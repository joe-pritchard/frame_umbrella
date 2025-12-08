defmodule FrameUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :frame_ui,
      version: "0.1.0",
      build_embedded: true,
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
    [
      extra_applications: [:logger],
      mod: {FrameUI.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
      {:scenic, "~> 0.11"},
      scenic_driver_local(),
      {:qrcode, "~> 0.1.1"}
    ]
  end

  defp scenic_driver_local do
    path = System.get_env("SCENIC_DRIVER_LOCAL_PATH", "")

    case File.exists?(path) do
      true ->
        {:scenic_driver_local, path: path}

      _ ->
        # Replace with hex.pm version when 0.12.0 is released
        {:scenic_driver_local,
         github: "ScenicFramework/scenic_driver_local", ref: "26cd49dee26bb5951e63e39b16840087c9b7d96f"}
    end
  end
end
