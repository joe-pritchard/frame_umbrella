defmodule FrameFirmware.FrameUISupervisor do
  @moduledoc """
  Supervisor which runs the Frame state manager which sends updates to the UI, and the Frame UI application itself.
  """
  use Supervisor

  @doc """
  Starts the FrameUISupervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_opts) do
    children = [
      FrameFirmware.FrameStateManager
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
