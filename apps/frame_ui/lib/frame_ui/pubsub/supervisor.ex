defmodule FrameUI.PubSub.Supervisor do
  @moduledoc """
  Supervisor for Scenic PubSub data publishers.
  """

  use Supervisor

  @type mode :: :undefined | :pending_wifi | :pending_enrollment | :pending_images | :active

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    [
      # add your data publishers here
      FrameUI.PubSub.FrameState
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end
end
