defmodule FrameCore.Backend do
  @moduledoc """
  GenServer that fetches image data from a remote backend server.
  """
  use GenServer

  require Logger

  @default_client Application.compile_env(:frame_core, :http_client, FrameCore.HttpClient.Real)

  defmodule Config do
    @moduledoc """
    Configuration for Backend GenServer.
    """

    @enforce_keys [:client]
    defstruct client: nil, backend_url: nil

    @type t :: %__MODULE__{
            client: module(),
            backend_url: String.t() | nil
          }
  end

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            client: module(),
            backend_url: String.t()
          }
    defstruct client: nil, backend_url: nil
  end

  ## Client API

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(%Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Authenticates the device with the backend server. A 200 response indicates successful enrolment.
  """
  @spec authenticate_device() :: {:ok, term()} | {:error, term()}
  def authenticate_device do
    GenServer.call(__MODULE__, :authenticate_device)
  end

  @doc """
  Fetches images from the backend, optionally filtering by last update time.
  """
  @spec fetch_images(DateTime.t() | nil) :: {:ok, list()} | {:error, term()}
  def fetch_images(last_fetch \\ nil) do
    GenServer.call(__MODULE__, {:fetch_images, last_fetch})
  end

  @spec download_file(String.t()) :: {:ok, binary()} | {:error, term()}
  def download_file(url) do
    GenServer.call(__MODULE__, {:download_file, url})
  end

  ## Server Callbacks

  @impl true
  @spec init(Config.t()) :: {:ok, State.t()}
  def init(%Config{client: client, backend_url: backend_url}) do
    actual_client = client || @default_client
    actual_url = backend_url || Application.fetch_env!(:frame_core, :backend_url)

    state = %State{
      client: actual_client,
      backend_url: actual_url
    }

    {:ok, state}
  end

  @impl true
  @spec handle_call(:authenticate_device, GenServer.from(), State.t()) ::
          {:reply, {:ok, term()} | {:error, term()}, State.t()}
  def handle_call(:authenticate_device, _from, %State{} = state) do
    case state.client.get_json("#{state.backend_url}/device-enrolment", %{}) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  @spec handle_call(
          {:fetch_images, DateTime.t() | nil},
          GenServer.from(),
          State.t()
        ) ::
          {:reply, {:ok, list()} | {:error, term()}, State.t()}
  def handle_call({:fetch_images, last_fetch}, _from, %State{} = state) do
    Logger.debug("Fetching images from backend with last_fetch: #{inspect(last_fetch)}")

    params = build_params(last_fetch)
    url = "#{state.backend_url}/images"

    case state.client.get_json(url, params) do
      {:ok, response} ->
        Logger.debug("Received response from backend: #{inspect(response)}")
        images = parse_images_response(response)
        {:reply, {:ok, images}, state}

      {:error, reason} = error ->
        Logger.warning("Failed to fetch images: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  ## todo: make async using Task.supervisor?
  @impl true
  @spec handle_call(
          {:download_file, String.t()},
          GenServer.from(),
          State.t()
        ) ::
          {:reply, {:ok, binary()} | {:error, term()}, State.t()}
  def handle_call({:download_file, url}, _from, %State{} = state) do
    Logger.debug("Downloading file from URL: #{url}")

    case state.client.get_file(url) do
      {:ok, body} ->
        Logger.debug("Successfully downloaded file with length: #{byte_size(body)}")
        {:reply, {:ok, body}, state}

      {:error, reason} = error ->
        Logger.warning("Failed to download file from #{url}: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  ## Private Functions

  defp build_params(nil), do: %{}

  defp build_params(%DateTime{} = last_fetch) do
    %{"since" => DateTime.to_iso8601(last_fetch)}
  end

  defp parse_images_response(%{"data" => images}) when is_list(images), do: images
  defp parse_images_response(_), do: []
end
