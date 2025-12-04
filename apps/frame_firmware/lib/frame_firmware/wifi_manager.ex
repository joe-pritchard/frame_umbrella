defmodule FrameFirmware.WifiManager do
  @moduledoc """
  GenServer that holds wifi connection state and kicks off vintage_net_wizard if not connected.
  When connected it calls `start_frame_core/1` (TODO).
  While connected it periodically checks connection health, and if disconnected it restarts
  vintage_net_wizard to try to reconnect.
  """

  use GenServer
  require Logger

  @wizard_ui_options [title: "Frame WiFi Setup", title_color: "blue", button_color: "#00FF00"]

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            connected: boolean(),
            is_wizard_running: boolean(),
            subscribers: [pid()]
          }

    @enforce_keys [:connected, :is_wizard_running]
    defstruct connected: false, is_wizard_running: false, subscribers: []
  end

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec subscribe(pid()) :: {:reply, :ok, State.t()}
  def subscribe(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  @spec handle_on_exit :: any()
  def handle_on_exit do
    GenServer.call(__MODULE__, :wizard_stopped)
  end

  # GenServer callbacks

  @impl true
  @spec init(any()) :: {:ok, State.t()}
  def init(_) do
    is_configured = VintageNetWizard.wifi_configured?("wlan0")

    VintageNetWizard.run_if_unconfigured(
      ifname: "wlan0",
      ui: @wizard_ui_options,
      on_exit: {__MODULE__, :handle_on_exit, []}
    )

    VintageNet.subscribe(["interface", "wlan0", "connection"])

    {:ok, %State{connected: is_configured, is_wizard_running: !is_configured}}
  end

  @impl true
  @spec handle_call({:subscribe, pid()}, GenServer.from(), State.t()) :: {:reply, :ok, State.t()}
  def handle_call({:subscribe, pid}, _from, state) do
    Logger.debug("WifiManager: #{inspect(pid)} is subscribing")

    # in case our subscriber subscribes after we've already configured the wifi,
    # just send the current state so we know they have it
    send(pid, {__MODULE__, if(state.connected, do: :wifi_configured, else: :wifi_unconfigured)})

    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  @spec handle_call(:wizard_stopped, GenServer.from(), State.t()) :: {:reply, :ok, State.t()}
  def handle_call(:wizard_stopped, _, state) do
    Logger.debug("WifiManager: wizard stopped")
    {:reply, :ok, %{state | is_wizard_running: false}}
  end

  @impl true
  @spec handle_info({module(), list(String.t()), term(), any(), any()}, State.t()) ::
          {:noreply, State.t()}
  def handle_info({VintageNet, ["interface", "wlan0", "connection"], connection_status, _, _}, state) do
    cond do
      connection_status == :disconnected and !state.is_wizard_running ->
        Logger.warning("WifiManager: disconnected, restarting wizard if needed")

        is_configured = VintageNetWizard.wifi_configured?("wlan0")

        VintageNetWizard.run_if_unconfigured(
          ifname: "wlan0",
          ui: @wizard_ui_options,
          on_exit: {__MODULE__, :handle_on_exit, []}
        )

        Logger.debug("WifiManager: is_configured=#{inspect(is_configured)}")

        notify_subscribers_if_unconfigured(is_configured, state)

        {:noreply, %{state | connected: is_configured, is_wizard_running: !is_configured}}

      connection_status == :disconnected and state.is_wizard_running ->
        Logger.debug("WifiManager: disconnected, wizard already running")

        {:noreply, %{state | connected: false}}

      connection_status in [:connected, :lan, :internet] ->
        Logger.info("WifiManager: connected to the internet! #{inspect(connection_status)}")

        Enum.each(state.subscribers, fn pid ->
          Logger.debug("Notifying subscriber #{inspect(pid)} of wifi_configured")
          send(pid, {__MODULE__, :wifi_configured})
        end)

        {:noreply, %{state | connected: true}}

      connection_status not in [:connected, :lan, :internet, :disconnected] ->
        Logger.debug("WifiManager: unknown connection status #{inspect(connection_status)}")
        {:noreply, state}
    end
  end

  @spec notify_subscribers_if_unconfigured(boolean(), State.t()) :: :ok
  defp notify_subscribers_if_unconfigured(false, state) do
    Enum.each(state.subscribers, fn pid ->
      Logger.debug("Notifying subscriber #{inspect(pid)} of wifi_unconfigured")
      send(pid, {__MODULE__, :wifi_unconfigured})
    end)

    :ok
  end

  defp notify_subscribers_if_unconfigured(_, _) do
    :ok
  end
end
