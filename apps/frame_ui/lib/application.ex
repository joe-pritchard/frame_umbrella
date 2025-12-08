defmodule FrameUI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    main_viewport_config =
      case Application.get_env(:frame_ui, :viewport) do
        nil ->
          raise "Missing :frame_ui, :viewport configuration for Scenic"

        config ->
          Keyword.put(config, :default_scene, {FrameUI.RootScene, nil})
      end

    children = [
      # Starts a worker by calling: FrameUI.Worker.start_link(arg)
      {
        Scenic,
        [main_viewport_config]
      },
      FrameUI.PubSub.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FrameUI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
