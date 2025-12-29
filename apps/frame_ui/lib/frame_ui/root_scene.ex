defmodule FrameUI.RootScene do
  @moduledoc """
  The root scene that displays the current mode of the frame. It receives updates from the framestate pubsub topic
  and delegates to other scene modules to display the right output based on the mode it calculates.
  """

  use Scenic.Scene

  alias FrameUI.Scenes.PendingEnrollment
  alias FrameUI.Scenes.PendingWifi
  alias Scenic.Graph

  require Logger

  ## PUBLIC API called by UI.Server

  ## SCENIC CALLBACKS

  @impl Scenic.Scene
  def init(scene, _params, _opts) do
    Scenic.PubSub.subscribe(:frame_state)

    {width, height} = scene.viewport.size
    {background, text} = {{220, 220, 220}, :black}

    initial_graph =
      Graph.build(font_size: 24, font: :roboto, fill: text)
      |> Scenic.Primitives.group(
        fn graph ->
          graph
        end,
        id: :main_group
      )
      |> Scenic.Primitives.rect({width, height}, fill: background)

    scene = assign(scene, graph: initial_graph, mode: :undefined)

    Logger.debug("FrameUI.RootScene: initialized with viewport size #{inspect(scene.viewport.size)}")

    {:ok, scene}
  end

  @doc false
  @impl GenServer
  @dialyzer {:nowarn_function, handle_info: 2}
  def handle_info(
        {{Scenic.PubSub, :data}, {:frame_state, frame_state, _ts}},
        %Scenic.Scene{assigns: %{graph: graph}} = scene
      ) do
    Logger.debug("FrameUI.RootScene: received frame state update: #{inspect(frame_state)}")

    [new_mode, new_graph] =
      cond do
        not frame_state.wifi_configured? and not frame_state.device_enrolled? ->
          [:pending_wifi, PendingWifi.build_graph(scene, frame_state.ssid)]

        not frame_state.device_enrolled? ->
          [:pending_enrollment, PendingEnrollment.build_graph(scene)]

        # currently we have not implemented images checking, but when we do this check should be enrolled AND has images
        # then we should have another case for enrolled but no images
        frame_state.device_enrolled? and frame_state.wifi_configured? ->
          [:active, graph]

        true ->
          [:undefined, graph]
      end

    scene =
      scene
      |> assign(graph: new_graph, mode: new_mode)
      |> push_graph(new_graph)

    {:noreply, scene}
  end

  @impl GenServer
  def handle_info({{Scenic.PubSub, :data}, data}, scene) do
    Logger.debug("FrameUI.RootScene: What the absolute heck have I received from PubSub? #{inspect(data)}")

    {:noreply, scene}
  end

  def handle_info({{Scenic.PubSub, :registered}, _}, scene) do
    {:noreply, scene}
  end
end
