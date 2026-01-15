defmodule FrameUI.Scenes.PendingEnrollment do
  @moduledoc """
  Scene for when there is wifi but the device is not yet enrolled. Just displays a message for now.
  """

  alias Scenic.Primitive
  alias Scenic.Primitives

  @margin 20

  @spec build_graph(Scenic.Scene.t()) :: Scenic.Graph.t()
  def build_graph(%Scenic.Scene{} = scene) do
    scene.assigns.graph
    |> Scenic.Graph.modify(
      :main_group,
      fn group ->
        Primitive.put(group, [])
      end
    )
    |> Scenic.Graph.add_to(:main_group, fn graph ->
      Primitives.text(graph, "Pending enrollment", translate: {@margin, @margin}, fill: :red)
    end)
  end
end
