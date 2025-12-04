defmodule FrameCore.HttpClient.Real do
  @moduledoc """
  Real HTTP client implementation using Req.
  """

  require Logger

  @behaviour FrameCore.HttpClient

  @impl true
  @spec get_json(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def get_json(url, params) do
    headers = [{"content-type", "application/json"}, {"X-Device-ID", FrameCore.DeviceId.get()}]

    Logger.debug("Making GET request to #{url} with params: #{inspect(params)}")

    case Req.get(url, params: params, headers: headers) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        Logger.debug("Received successful response with status #{status}")
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("HTTP error with status #{status}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.warning("Request failed with reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  @spec get_file(String.t()) :: {:ok, binary()} | {:error, term()}
  def get_file(url) do
    headers = [{"X-Device-ID", FrameCore.DeviceId.get()}]

    case Req.get(url, headers: headers) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
