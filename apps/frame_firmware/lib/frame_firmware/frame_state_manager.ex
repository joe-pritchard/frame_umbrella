defmodule FrameFirmware.FrameStateManager do
  @moduledoc """
  Responsible for tracking the current state of the Frame device, including wifi connection, enrolment status, etc.
  """

  use GenServer
  require Logger

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            wifi_configured?: boolean(),
            device_enrolled?: boolean()
          }

    defstruct wifi_configured?: false, device_enrolled?: false
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
    Process.send_after(self(), :check_enrolment, 1_000)

    new_state = %{state | wifi_configured?: true}
    send(FrameUI.PubSub.FrameState, {:frame_state, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({FrameFirmware.WifiManager, :wifi_unconfigured}, state) do
    new_state = %{state | wifi_configured?: false}
    send(FrameUI.PubSub.FrameState, {:frame_state, new_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_enrolment, %{wifi_configured?: true} = state) do
    enrolled? = FrameCore.Enrolment.check_enrolment()

    unless enrolled? do
      Process.send_after(self(), :check_enrolment, 1_000)
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
  def handle_info(_msg, state) do
    Logger.debug("FrameStateManager received unexpected message: #{inspect(_msg)}")
    {:noreply, state}
  end
end
