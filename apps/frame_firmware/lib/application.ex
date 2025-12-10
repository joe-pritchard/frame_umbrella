defmodule FrameFirmware.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Logger.configure(level: :debug)

    children =
      [
        # Children for all targets
        # Starts a worker by calling: FrameFirmware.Worker.start_link(arg)
        # {FrameFirmware.Worker, arg},
      ] ++ target_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FrameFirmware.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  if Mix.target() == :host do
    defp target_children do
      [
        # Children that only run on the host during development or test.
        # In general, prefer using `config/host.exs` for differences.
        #
        # Starts a worker by calling: Host.Worker.start_link(arg)
        # {Host.Worker, arg},
      ]
    end
  else
    defp target_children do
      [
        # Children for all targets except host
        # Starts a worker by calling: Target.Worker.start_link(arg)
        # {Target.Worker, arg},
        {FrameFirmware.WifiManager, []},
        {FrameFirmware.FrameCoreSupervisor, []},
        {FrameFirmware.FrameUISupervisor, []}
      ]
    end
  end
end
