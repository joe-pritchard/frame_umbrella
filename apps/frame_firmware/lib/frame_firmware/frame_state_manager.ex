defmodule FrameFirmware.FrameStateManager do
  @moduledoc """
  Responsible for tracking the current state of the Frame device, including wifi connection, enrolment status, etc.
  """

  use GenServer
  require Logger

  defmodule State do
    @moduledoc false
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
    {:noreply, %{state | wifi_configured?: true}}
  end

  @impl true
  def handle_info({FrameFirmware.WifiManager, :wifi_unconfigured}, state) do
    {:noreply, %{state | wifi_configured?: false}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
