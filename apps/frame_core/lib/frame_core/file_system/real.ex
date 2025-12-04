defmodule FrameCore.FileSystem.Real do
  @moduledoc """
  Real file system implementation.
  """

  require Logger

  @behaviour FrameCore.FileSystem

  @impl true
  def read(path), do: File.read(path)

  @impl true
  def write!(path, content), do: File.write!(path, content)

  @impl true
  def list_dir(path) do
    Logger.debug("listing files in #{path}")

    case File.ls(path) do
      {:ok, files} ->
        Logger.debug("Found #{length(files)} files in #{path}")

        # Return full paths, not just filenames
        full_paths = Enum.map(files, fn file -> Path.join(path, file) end)
        {:ok, full_paths}

      {:error, _} = error ->
        Logger.debug("Error listing files in #{path}: #{inspect(error)}")
        error
    end
  end

  @impl true
  def rm(path) do
    Logger.debug("removing #{path}")

    case File.rm(path) do
      :ok ->
        Logger.debug("Successfully removed #{path}")
        :ok

      {:error, reason} ->
        Logger.debug("Error removing #{path}: #{inspect(reason)}")

        {:error, reason}
    end
  end

  @impl true
  def mkdir_p(path) do
    Logger.debug("Creating directory path: #{path}")

    case File.mkdir_p(path) do
      :ok ->
        Logger.debug("Successfully created directory path: #{path}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to create directory path #{path}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
