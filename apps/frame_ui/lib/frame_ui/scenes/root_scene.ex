defmodule FrameUI.RootScene do
  @moduledoc """
  The root scene that displays the current mode of the frame. It receives updates from the framestate pubsub topic
  and delegates to other scene modules to display the right output based on the mode it calculates.
  """

  use Scenic.Scene
  alias Scenic.Graph

  ## PUBLIC API called by UI.Server

  ## SCENIC CALLBACKS

  @impl Scenic.Scene
  def init(scene, _current_scene, _opts) do
    Scenic.PubSub.subscribe(:frame_state)

    scene = push_graph(scene, build_graph(:undefined, scene))

    {:ok, scene}
  end

  @doc false
  @impl GenServer
  def handle_info({{Scenic.PubSub, :data}, {:frame_state, frame_state, _ts}}, scene) do
    new_mode =
      cond do
        not frame_state.wifi_configured? and not frame_state.device_enrolled? ->
          :pending_wifi

        not frame_state.device_enrolled? ->
          :pending_enrollment

        # currently we have not implemented images checking, but when we do this check should be enrolled AND has images
        # then we should have another case for enrolled but no images
        frame_state.device_enrolled? and frame_state.wifi_configured? ->
          :active

        true ->
          :undefined
      end

    scene = push_graph(scene, build_graph(new_mode, scene))

    {:noreply, scene}
  end

  def handle_info({{Scenic.PubSub, :registered}, _}, scene) do
    {:noreply, scene}
  end

  defp build_graph(mode, scene) do
    {width, height} = scene.viewport.size
    {background, text} = {{220, 220, 220}, :black}

    Graph.build(font_size: 24, font: :roboto)
    |> Scenic.Primitives.rect({width, height}, fill: background)
    |> Scenic.Primitives.text("Scene:", translate: {15, 38}, align: :right, fill: text)
    |> Scenic.Primitives.text(inspect(mode), translate: {15, 60}, fill: text)
  end
end
