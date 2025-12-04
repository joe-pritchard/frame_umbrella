defmodule FrameCore.DeviceId do
  @moduledoc """
  GenServer that manages a persistent device identifier.

  Reads or generates a UUID and stores it in a file to persist across restarts.
  """
  require Logger

  use GenServer

  @device_id_path "device_id.txt"

  defmodule Config do
    @moduledoc """
    Configuration for DeviceId GenServer.
    """

    defstruct file_system: FrameCore.FileSystem.Real

    @type t :: %__MODULE__{
            file_system: module()
          }
  end

  @type state :: String.t()

  ## Client API

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(%Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @spec get() :: String.t()
  def get, do: GenServer.call(__MODULE__, :get)

  ## Server Callbacks

  @impl GenServer
  @spec init(Config.t()) :: {:ok, state()} | {:stop, term()}
  def init(%Config{file_system: file_system}) do
    case load_or_generate_id(file_system) do
      {:ok, id} ->
        {:ok, id}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  @spec handle_call(:get, GenServer.from(), state()) :: {:reply, String.t(), state()}
  def handle_call(:get, _from, id), do: {:reply, id, id}

  defp load_or_generate_id(file_system) do
    case file_system.read(@device_id_path) do
      {:ok, content} ->
        id = String.trim(content)
        Logger.debug("Loaded existing device ID: #{id}")
        {:ok, id}

      {:error, :enoent} ->
        Logger.debug("No existing device ID, generating...")
        generate_and_persist_id(file_system)

      {:error, reason} ->
        Logger.warning("Failed to read device ID file: #{inspect(reason)}")
        {:error, {:device_id_read_failed, reason}}
    end
  end

  defp generate_and_persist_id(file_system) do
    new_id = UUID.uuid4()

    case persist_id(file_system, new_id) do
      :ok ->
        Logger.debug("Generated new device ID: #{new_id}")
        {:ok, new_id}

      {:error, reason} ->
        Logger.warning("Failed to persist device ID: #{inspect(reason)}")
        {:error, {:device_id_write_failed, reason}}
    end
  end

  defp persist_id(file_system, id) do
    file_system.write!(@device_id_path, id)
    :ok
  rescue
    error -> {:error, error}
  end
end
