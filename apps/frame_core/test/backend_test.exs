defmodule FrameCore.BackendTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  alias FrameCore.Backend

  describe "Backend.fetch_images/1" do
    test "fetches images with device ID in header and no last_fetch param" do
      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/images"
        assert params == %{}

        {:ok, %{"data" => [%{"id" => 1, "url" => "http://example.com/img1.jpg"}]}}
      end)

      config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      {:ok, _pid} = start_supervised({Backend, config})

      assert {:ok, images} = Backend.fetch_images()
      assert length(images) == 1
      assert [%{"id" => 1, "url" => "http://example.com/img1.jpg"}] = images
    end

    test "includes since parameter when last_fetch is provided" do
      last_fetch = ~U[2025-11-24 12:00:00Z]

      expect(FrameCore.HttpClientMock, :get_json, fn url, params ->
        assert url == "https://api.example.com/images"
        assert params == %{"since" => "2025-11-24T12:00:00Z"}

        {:ok, %{"data" => []}}
      end)

      config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      {:ok, _pid} = start_supervised({Backend, config})

      assert {:ok, []} = Backend.fetch_images(last_fetch)
    end

    test "handles empty images array in response" do
      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => []}}
      end)

      config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      {:ok, _pid} = start_supervised({Backend, config})

      assert {:ok, []} = Backend.fetch_images()
    end

    test "handles missing images key in response" do
      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"status" => "ok"}}
      end)

      config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      {:ok, _pid} = start_supervised({Backend, config})

      assert {:ok, []} = Backend.fetch_images()
    end

    test "handles HTTP client errors" do
      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:error, :timeout}
      end)

      config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      {:ok, _pid} = start_supervised({Backend, config})

      assert {:error, :timeout} = Backend.fetch_images()
    end

    test "fetches multiple images correctly" do
      images_data = [
        %{"id" => 1, "url" => "http://example.com/img1.jpg", "title" => "Image 1"},
        %{"id" => 2, "url" => "http://example.com/img2.jpg", "title" => "Image 2"},
        %{"id" => 3, "url" => "http://example.com/img3.jpg", "title" => "Image 3"}
      ]

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => images_data}}
      end)

      config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      {:ok, _pid} = start_supervised({Backend, config})

      assert {:ok, images} = Backend.fetch_images()
      assert length(images) == 3
      assert images == images_data
    end
  end
end
