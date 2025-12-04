defmodule FrameCore.FileSystem do
  @moduledoc """
  Behavior for file system operations.
  """

  @type path :: Path.t()
  @type posix_error :: File.posix()

  @callback read(path()) :: {:ok, binary()} | {:error, posix_error()}
  @callback write!(path(), iodata()) :: :ok
  @callback list_dir(path()) :: {:ok, [String.t()]} | {:error, posix_error()}
  @callback rm(path()) :: :ok | {:error, posix_error()}
  @callback mkdir_p(path()) :: :ok | {:error, posix_error()}
end
