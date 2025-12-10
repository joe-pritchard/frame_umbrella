defmodule FrameFirmware.FrameCoreSupervisor do
  @moduledoc """
  Supervisor responsible for Frame Core processes (not slideshow) using a rest-for-one strategy.
  """

  use Supervisor

  @doc """
  Starts the FrameCoreSupervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_opts) do
    children = [
      {FrameCore.DeviceId, %FrameCore.DeviceId.Config{}},
      {FrameCore.Backend, %FrameCore.Backend.Config{client: nil}},
      FrameCore.Enrolment
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
