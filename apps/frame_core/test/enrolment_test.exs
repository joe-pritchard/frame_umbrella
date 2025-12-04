defmodule FrameCore.EnrolmentTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    config = %FrameCore.Backend.Config{
      client: FrameCore.HttpClientMock,
      backend_url: "https://api.example.com"
    }

    start_supervised({FrameCore.Backend, config})
    start_supervised(FrameCore.Enrolment)

    :ok
  end

  describe "Enrolment.check_enrolment" do
    test "returns true when device is successfully enrolled" do
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:ok, ""}
      end)

      assert FrameCore.Enrolment.check_enrolment() == true
    end

    test "returns false when the server returns a client error" do
      # make sure the first call succeeds, that way we know the second
      # false result is from the client error, not from the initial state
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:ok, ""}
      end)

      assert FrameCore.Enrolment.check_enrolment() == true

      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:error, {:http_error, 401}}
      end)

      assert FrameCore.Enrolment.check_enrolment() == false
    end

    test "does not change state when the server returns a server error" do
      # initially true
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:ok, ""}
      end)

      assert FrameCore.Enrolment.check_enrolment() == true

      # still true, because we don't get a definitive answer
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:error, {:http_error, 500}}
      end)

      assert FrameCore.Enrolment.check_enrolment() == true

      # still true, because we can't even reach the server
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:error, :timeout}
      end)

      assert FrameCore.Enrolment.check_enrolment() == true

      # now we get a false
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:error, {:http_error, 401}}
      end)

      assert FrameCore.Enrolment.check_enrolment() == false

      # and it stays false
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/device-enrolment"
        assert params == %{}

        {:error, {:http_error, 500}}
      end)

      assert FrameCore.Enrolment.check_enrolment() == false
    end
  end
end
