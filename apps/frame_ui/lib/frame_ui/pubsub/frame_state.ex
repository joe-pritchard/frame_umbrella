defmodule FrameUI.PubSub.FrameState do
  @moduledoc """
  A Scenic PubSub publisher for the frame's state, including wifi and enrollment status. Received from FrameFirmware.FrameStateManager.
  """

  use GenServer

  alias Scenic.PubSub

  @name :frame_state
  @version "0.1.0"
  @description "A publisher for the frame's state, including wifi and enrollment status. Received from FrameFirmware.FrameStateManager"

  # --------------------------------------------------------
  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  # --------------------------------------------------------
  @impl true
  def init(_) do
    # register this sensor
    PubSub.register(@name, version: @version, description: @description)

    {:ok, %{t: 0}}
  end

  @impl true
  def handle_info({@name, frame_state}, state) do
    PubSub.publish(@name, frame_state)

    {:noreply, state}
  end
end
