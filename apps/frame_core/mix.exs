defmodule FrameCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :frame_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    case Mix.env() do
      :prod ->
        [
          extra_applications: [:logger],
          mod: {FrameCore.Application, []}
        ]

      :test ->
        [extra_applications: [:logger, :mox]]

      _ ->
        [extra_applications: [:logger]]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:req, "~> 0.5"}
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end
end
