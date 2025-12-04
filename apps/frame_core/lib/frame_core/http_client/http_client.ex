defmodule FrameCore.HttpClient do
  @moduledoc """
  Behavior for HTTP client operations.
  """

  @type url :: String.t()
  @type params :: map()
  @type json_response :: term()
  @type error :: {:error, term()}

  @callback get_json(url(), params()) :: {:ok, json_response()} | error()
  @callback get_file(url()) :: {:ok, binary()} | error()
end
