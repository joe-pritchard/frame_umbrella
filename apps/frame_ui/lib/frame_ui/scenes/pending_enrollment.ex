defmodule FrameUI.Scenes.PendingEnrollment do
  @moduledoc """
  Scene for when there is wifi but the device is not yet enrolled. Just displays a message for now.
  """

  alias Scenic.Primitives

  @margin 20

  @spec build_graph(Scenic.Scene.t()) :: Scenic.Graph.t()
  def build_graph(%{viewport: %{size: {width, height}}} = scene) do
    scene.assigns.graph
    |> Primitives.text("Pending enrollment", translate: {@margin, @margin}, fill: :red)
  end
end
