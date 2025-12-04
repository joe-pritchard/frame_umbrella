defmodule FrameCore.Slideshow do
  @moduledoc """
  GenServer that manages the image slideshow.

  Fetches images from the Backend, persists the last fetch timestamp,
  downloads new images, deletes removed images, and provides random
  image selection for display.
  """

  use GenServer
  require Logger

  alias FrameCore.Backend

  @last_fetch_path "last_fetch.txt"
  @images_dir "images"

  defmodule Config do
    @moduledoc """
    Configuration for Slideshow GenServer.
    """

    defstruct file_system: FrameCore.FileSystem.Real

    @type t :: %__MODULE__{
            file_system: module()
          }
  end

  defmodule State do
    @moduledoc """
    Internal state for Slideshow GenServer.
    """

    @type t :: %__MODULE__{
            file_system: module(),
            last_fetch: DateTime.t() | nil,
            images: [String.t()]
          }

    defstruct [:file_system, :last_fetch, images: []]
  end

  ## Client API

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(%Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Fetches new images from the backend and updates local image cache.
  """
  @spec refresh() :: :ok | {:error, term()}
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  @doc """
  Returns a random image path from the available images.
  """
  @spec get_random_image() :: {:ok, String.t()} | {:error, :no_images}
  def get_random_image do
    GenServer.call(__MODULE__, :get_random_image)
  end

  @doc """
  Returns list of all available image paths.
  """
  @spec list_images() :: [String.t()]
  def list_images do
    GenServer.call(__MODULE__, :list_images)
  end

  ## Server Callbacks

  @impl true
  @spec init(Config.t()) :: {:ok, State.t()}
  def init(%Config{file_system: file_system}) do
    # Load last fetch timestamp from file
    last_fetch = load_last_fetch(file_system)

    # Scan images directory for existing images
    images = scan_images_directory(file_system)

    state = %State{
      file_system: file_system,
      last_fetch: last_fetch,
      images: images
    }

    Logger.info("Slideshow initialized with #{length(images)} images")

    {:ok, state}
  end

  @impl true
  @spec handle_call(:refresh, GenServer.from(), State.t()) ::
          {:reply, :ok | {:error, term()}, State.t()}
  def handle_call(:refresh, _from, state) do
    case Backend.fetch_images(state.last_fetch) do
      {:ok, image_data} ->
        Logger.info("Fetched #{length(image_data)} images from backend")
        # Process each image (download new, delete removed)
        new_state = process_images(image_data, state)

        # Update last_fetch timestamp
        now = DateTime.utc_now()
        save_last_fetch(state.file_system, now)

        new_state = %{new_state | last_fetch: now}

        Logger.info("Refreshed images, new length: #{length(new_state.images)}")
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.warning("Failed to refresh images: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  @spec handle_call(:get_random_image, GenServer.from(), State.t()) ::
          {:reply, {:ok, String.t()} | {:error, :no_images}, State.t()}
  def handle_call(:get_random_image, _from, state) do
    case state.images do
      [] ->
        Logger.debug("No images available for random selection")
        {:reply, {:error, :no_images}, state}

      images ->
        random_index = :rand.uniform(length(images) - 1)

        Logger.debug("Selected random image index: #{random_index}")
        image = Enum.at(images, random_index)
        Logger.debug("image selected: #{image}")
        {:reply, {:ok, image}, state}
    end
  end

  @impl true
  @spec handle_call(:list_images, GenServer.from(), State.t()) ::
          {:reply, [String.t()], State.t()}
  def handle_call(:list_images, _from, state) do
    {:reply, state.images, state}
  end

  ## Private Functions

  @spec load_last_fetch(module()) :: DateTime.t() | nil
  defp load_last_fetch(file_system) do
    case file_system.read(@last_fetch_path) do
      {:ok, content} ->
        case DateTime.from_iso8601(String.trim(content)) do
          {:ok, datetime, _offset} ->
            Logger.debug("Loaded last fetch time: #{content}")
            datetime

          {:error, reason} ->
            Logger.debug(
              "Unable to generate DateTime from last fetch content, returning nil: #{inspect(reason)}"
            )

            nil
        end

      {:error, _} ->
        Logger.debug("last fetch does not exist, returning nil")
        nil
    end
  end

  @spec save_last_fetch(module(), DateTime.t()) :: :ok
  defp save_last_fetch(file_system, datetime) do
    iso_string = DateTime.to_iso8601(datetime)
    file_system.write!(@last_fetch_path, iso_string)
    :ok
  end

  @spec scan_images_directory(module()) :: [String.t()]
  defp scan_images_directory(file_system) do
    case file_system.list_dir(@images_dir) do
      {:ok, files} ->
        # Filter for image files only (jpg, jpeg, png, gif)
        Enum.filter(files, fn path ->
          ext = Path.extname(path) |> String.downcase()
          ext in [".jpg", ".jpeg", ".png", ".gif"]
        end)

      {:error, :enoent} ->
        # Directory doesn't exist yet - that's ok
        []

      {:error, reason} ->
        Logger.warning("Failed to scan images directory: #{inspect(reason)}")
        []
    end
  end

  @spec process_images([map()], State.t()) :: State.t()
  defp process_images(image_data, state) do
    result =
      Enum.reduce(image_data, state, fn image, acc_state ->
        process_single_image(image, acc_state)
      end)

    result
  end

  @spec process_single_image(map(), State.t()) :: State.t()
  defp process_single_image(%{"deleted_at" => nil} = image, state) do
    # Image should exist - download if not present
    image_path = get_image_path(image)

    if image_path in state.images do
      Logger.debug("Image #{image_path} already exists, skipping")
      state
    else
      Logger.debug("Downloading image id #{image["id"]} from: #{image["url"]}")

      case download_image(image, image_path, state.file_system) do
        :ok ->
          Logger.debug("Successfully downloaded #{image_path}, adding to state")
          %{state | images: [image_path | state.images]}

        {:error, reason} ->
          Logger.warning("Failed to download image: #{inspect(reason)}")
          state
      end
    end
  end

  defp process_single_image(%{"deleted_at" => _deleted_at} = image, state) do
    # Image should be deleted
    image_path = get_image_path(image)

    if image_path in state.images do
      # Remove from file system
      Logger.debug("Deleting image: #{image_path}")

      case state.file_system.rm(image_path) do
        :ok ->
          Logger.debug("Successfully deleted #{image_path}, removing from state")
          %{state | images: List.delete(state.images, image_path)}

        {:error, reason} ->
          Logger.warning("Failed to delete image #{image_path}: #{inspect(reason)}")
          state
      end
    else
      state
    end
  end

  @spec get_image_path(map()) :: String.t()
  defp get_image_path(%{"id" => id, "url" => url}) do
    extension =
      url
      |> URI.parse()
      |> Map.get(:path, "")
      |> Path.extname()
      |> case do
        # default
        "" -> ".jpg"
        ext -> ext
      end

    Path.join(@images_dir, "#{id}#{extension}")
  end

  @spec download_image(map(), String.t(), module()) :: :ok | {:error, term()}
  defp download_image(%{"url" => url}, destination, file_system) do
    case file_system.mkdir_p(Path.dirname(destination)) do
      :ok ->
        case Backend.download_file(url) do
          {:ok, data} ->
            file_system.write!(destination, data)
            Logger.info("Downloaded #{url} to #{destination}")
            :ok

          {:error, reason} ->
            Logger.warning("Failed to download #{url} to #{destination}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.warning("Failed to create directory for #{destination}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
