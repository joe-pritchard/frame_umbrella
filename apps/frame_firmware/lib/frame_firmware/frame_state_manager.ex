defmodule FrameFirmware.FrameStateManager do
  @moduledoc """
  Responsible for tracking the current state of the Frame device, including wifi connection, enrolment status, etc.
  """

  use GenServer
  require Logger

  @enrollment_check_interval_ms 60_000

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            wifi_configured?: boolean(),
            device_enrolled?: boolean(),
            ssid: String.t() | nil
          }

    defstruct wifi_configured?: false, device_enrolled?: false, ssid: nil
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    FrameFirmware.WifiManager.subscribe(self())

    {:ok, %State{}}
  end

  @impl true
  def handle_info({FrameFirmware.WifiManager, :wifi_configured}, state) do
    Process.send_after(self(), :check_enrolment, @enrollment_check_interval_ms)

    new_state = %{state | wifi_configured?: true}
    send(FrameUI.PubSub.FrameState, {:frame_state, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({FrameFirmware.WifiManager, :wifi_unconfigured}, state) do
    ssid = VintageNetWizard.APMode.ssid()

    new_state = %{state | wifi_configured?: false, ssid: ssid}

    send(FrameUI.PubSub.FrameState, {:frame_state, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_enrolment, %{wifi_configured?: true} = state) do
    enrolled? = FrameCore.Enrolment.check_enrolment()

    unless enrolled? do
      Process.send_after(self(), :check_enrolment, @enrollment_check_interval_ms)
    end

    new_state = %{state | device_enrolled?: enrolled?}
    send(FrameUI.PubSub.FrameState, {:frame_state, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_enrolment, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("FrameStateManager: received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
