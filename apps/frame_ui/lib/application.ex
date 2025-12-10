defmodule FrameUI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: FrameUI.Worker.start_link(arg)
      {
        Scenic,
        [Application.get_env(:frame_ui, :viewport)]
      },
      FrameUI.PubSub.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FrameUI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
