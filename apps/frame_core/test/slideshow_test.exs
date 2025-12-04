defmodule FrameCore.SlideshowTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  alias FrameCore.Backend
  alias FrameCore.Slideshow

  describe "Slideshow" do
    test "initializes with existing images from filesystem" do
      expect(FrameCore.FileSystemMock, :read, fn "last_fetch.txt" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:ok, ["images/1.jpg", "images/2.png", "images/3.gif"]}
      end)

      config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, config})

      images = Slideshow.list_images()
      assert length(images) == 3
      assert "images/1.jpg" in images
      assert "images/2.png" in images
      assert "images/3.gif" in images
    end

    test "returns error when no images available" do
      expect(FrameCore.FileSystemMock, :read, fn "last_fetch.txt" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:error, :enoent}
      end)

      config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, config})

      assert {:error, :no_images} = Slideshow.get_random_image()
    end

    test "refresh fetches images from backend and saves last_fetch" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, fn "last_fetch.txt", content ->
        assert {:ok, _dt, _offset} = DateTime.from_iso8601(content)
        :ok
      end)

      expect(FrameCore.HttpClientMock, :get_json, fn _url, params ->
        # no last_fetch date provided
        assert params == %{}
        {:ok, %{"images" => []}}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      assert :ok = Slideshow.refresh()
    end

    test "refresh passes last_fetch to backend" do
      last_fetch = ~U[2025-11-24 10:00:00Z]
      iso_string = DateTime.to_iso8601(last_fetch)

      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:ok, iso_string}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, fn "last_fetch.txt", _content ->
        :ok
      end)

      expect(FrameCore.HttpClientMock, :get_json, fn _url, params ->
        assert params["since"] == iso_string
        {:ok, %{"images" => []}}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      assert :ok = Slideshow.refresh()
    end

    test "handles backend errors gracefully" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:error, :enoent}
      end)

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:error, :timeout}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      assert {:error, :timeout} = Slideshow.refresh()
    end

    test "get_random_image returns an image from available images" do
      expect(FrameCore.FileSystemMock, :read, fn "last_fetch.txt" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:ok, ["images/1.jpg", "images/2.jpg"]}
      end)

      config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, config})

      assert {:ok, image} = Slideshow.get_random_image()
      assert is_binary(image)
      assert image in ["images/1.jpg", "images/2.jpg"]
    end

    test "list_images returns all available images" do
      expect(FrameCore.FileSystemMock, :read, fn "last_fetch.txt" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:ok, ["images/1.jpg", "images/2.png"]}
      end)

      config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, config})

      images = Slideshow.list_images()
      assert length(images) == 2
      assert "images/1.jpg" in images
      assert "images/2.png" in images
    end

    test "refresh downloads new images that don't exist" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:ok, ["images/1.jpg"]}
      end)

      expect(FrameCore.FileSystemMock, :write!, 3, fn path, _content ->
        assert path in ["last_fetch.txt", "images/2.jpg", "images/3.jpg"]
        :ok
      end)

      expect(FrameCore.FileSystemMock, :mkdir_p, 2, fn "images" ->
        :ok
      end)

      # Backend returns 2 new images and 1 existing
      images_data = [
        %{"id" => 1, "url" => "http://example.com/img1.jpg", "deleted_at" => nil},
        %{"id" => 2, "url" => "http://example.com/img2.jpg", "deleted_at" => nil},
        %{"id" => 3, "url" => "http://example.com/img3.jpg", "deleted_at" => nil}
      ]

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => images_data}}
      end)

      expect(FrameCore.HttpClientMock, :get_file, 2, fn url ->
        assert url in ["http://example.com/img2.jpg", "http://example.com/img3.jpg"]
        {:ok, <<>>}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      # Initial state has 1 image
      assert length(Slideshow.list_images()) == 1

      assert :ok = Slideshow.refresh()

      # After refresh, should have 3 images (1 existing + 2 new downloaded)
      images = Slideshow.list_images()
      assert length(images) == 3
      assert "images/1.jpg" in images
      assert "images/2.jpg" in images
      assert "images/3.jpg" in images
    end

    test "refresh deletes images with deleted_at set" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:ok, ["images/1.jpg", "images/2.jpg"]}
      end)

      expect(FrameCore.FileSystemMock, :write!, fn "last_fetch.txt", _content ->
        :ok
      end)

      expect(FrameCore.FileSystemMock, :rm, fn "images/2.jpg" ->
        :ok
      end)

      # Backend returns image 2 as deleted
      images_data = [
        %{"id" => 1, "url" => "http://example.com/img1.jpg", "deleted_at" => nil},
        %{
          "id" => 2,
          "url" => "http://example.com/img2.jpg",
          "deleted_at" => "2025-11-24T10:00:00Z"
        }
      ]

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => images_data}}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      # Initial state has 2 images
      assert length(Slideshow.list_images()) == 2

      assert :ok = Slideshow.refresh()

      # After refresh, should have 1 image (deleted images/2.jpg)
      images = Slideshow.list_images()
      assert length(images) == 1
      assert "images/1.jpg" in images
      refute "images/2.jpg" in images
    end

    test "refresh both downloads new and deletes removed images" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:ok, ["images/1.jpg", "images/2.jpg"]}
      end)

      expect(FrameCore.FileSystemMock, :write!, 2, fn path, _content ->
        assert path in ["last_fetch.txt", "images/3.jpg"]
        :ok
      end)

      expect(FrameCore.FileSystemMock, :rm, fn "images/2.jpg" ->
        :ok
      end)

      expect(FrameCore.FileSystemMock, :mkdir_p, fn "images" ->
        :ok
      end)

      # Backend returns: keep img1, delete img2, add img3
      images_data = [
        %{"id" => 1, "url" => "http://example.com/img1.jpg", "deleted_at" => nil},
        %{
          "id" => 2,
          "url" => "http://example.com/img2.jpg",
          "deleted_at" => "2025-11-24T10:00:00Z"
        },
        %{"id" => 3, "url" => "http://example.com/img3.jpg", "deleted_at" => nil}
      ]

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => images_data}}
      end)

      expect(FrameCore.HttpClientMock, :get_file, fn url ->
        assert url == "http://example.com/img3.jpg"
        {:ok, <<>>}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      # Initial state has 2 images
      assert length(Slideshow.list_images()) == 2

      assert :ok = Slideshow.refresh()

      # After refresh, should have 2 images (deleted img2, added img3)
      images = Slideshow.list_images()
      assert length(images) == 2
      assert "images/1.jpg" in images
      refute "images/2.jpg" in images
      assert "images/3.jpg" in images
    end

    test "handles URLs with query parameters correctly" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, 2, fn path, _content ->
        # Should extract .jpg from path, not include query params
        assert path in ["last_fetch.txt", "images/100.jpg"]
        refute String.contains?(path, "?")
        refute String.contains?(path, "size=large")
        :ok
      end)

      expect(FrameCore.FileSystemMock, :mkdir_p, fn "images" ->
        :ok
      end)

      # Image URL has query parameters
      images_data = [
        %{
          "id" => 100,
          "url" => "http://example.com/photo.jpg?size=large&token=abc123",
          "deleted_at" => nil
        }
      ]

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => images_data}}
      end)

      expect(FrameCore.HttpClientMock, :get_file, fn url ->
        assert url == "http://example.com/photo.jpg?size=large&token=abc123"
        {:ok, <<>>}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      assert :ok = Slideshow.refresh()

      images = Slideshow.list_images()
      assert length(images) == 1
      assert "images/100.jpg" in images
    end

    test "handles URLs without file extensions by defaulting to .jpg" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, 2, fn path, _content ->
        # Should default to .jpg when no extension found
        assert path in ["last_fetch.txt", "images/200.jpg"]
        :ok
      end)

      expect(FrameCore.FileSystemMock, :mkdir_p, fn "images" ->
        :ok
      end)

      # Image URL has no file extension
      images_data = [
        %{
          "id" => 200,
          "url" => "http://example.com/api/image/get",
          "deleted_at" => nil
        }
      ]

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => images_data}}
      end)

      expect(FrameCore.HttpClientMock, :get_file, fn url ->
        assert url == "http://example.com/api/image/get"
        {:ok, <<>>}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      assert :ok = Slideshow.refresh()

      images = Slideshow.list_images()
      assert length(images) == 1
      assert "images/200.jpg" in images
    end

    test "preserves correct extensions from URLs with query parameters" do
      expect(FrameCore.FileSystemMock, :read, fn filename ->
        case filename do
          "device_id.txt" -> {:ok, "test-device-123"}
          "last_fetch.txt" -> {:error, :enoent}
        end
      end)

      expect(FrameCore.FileSystemMock, :list_dir, fn "images" ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, 4, fn path, _content ->
        # Should extract correct extension for each file type
        assert path in [
                 "last_fetch.txt",
                 "images/301.png",
                 "images/302.gif",
                 "images/303.jpeg"
               ]

        :ok
      end)

      expect(FrameCore.FileSystemMock, :mkdir_p, 3, fn "images" ->
        :ok
      end)

      # Different image types with query params
      images_data = [
        %{
          "id" => 301,
          "url" => "http://example.com/photo.png?w=800&h=600",
          "deleted_at" => nil
        },
        %{
          "id" => 302,
          "url" => "http://example.com/animation.gif?autoplay=false",
          "deleted_at" => nil
        },
        %{
          "id" => 303,
          "url" => "http://example.com/image.jpeg?quality=high",
          "deleted_at" => nil
        }
      ]

      expect(FrameCore.HttpClientMock, :get_json, fn _url, _params ->
        {:ok, %{"data" => images_data}}
      end)

      expect(FrameCore.HttpClientMock, :get_file, 3, fn url ->
        assert url in [
                 "http://example.com/photo.png?w=800&h=600",
                 "http://example.com/animation.gif?autoplay=false",
                 "http://example.com/image.jpeg?quality=high"
               ]

        {:ok, <<>>}
      end)

      backend_config = %Backend.Config{
        client: FrameCore.HttpClientMock,
        backend_url: "https://api.example.com"
      }

      start_supervised({Backend, backend_config})

      slideshow_config = %Slideshow.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({Slideshow, slideshow_config})

      assert :ok = Slideshow.refresh()

      images = Slideshow.list_images()
      assert length(images) == 3
      assert "images/301.png" in images
      assert "images/302.gif" in images
      assert "images/303.jpeg" in images
    end
  end
end
