defmodule FrameCore.DeviceIdTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  alias FrameCore.DeviceId

  describe "DeviceId" do
    test "writes a uuid to file if one does not exist" do
      path = "device_id.txt"

      expect(FrameCore.FileSystemMock, :read, fn ^path ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, fn ^path, content ->
        assert byte_size(content) == 36
        :ok
      end)

      config = %DeviceId.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({DeviceId, config})

      device_id = DeviceId.get()
      assert byte_size(device_id) == 36
    end

    test "returns the uuid from file if it already exists" do
      path = "device_id.txt"
      existing_uuid = "550e8400-e29b-41d4-a716-446655440000"

      expect(FrameCore.FileSystemMock, :read, fn ^path ->
        {:ok, existing_uuid}
      end)

      config = %DeviceId.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, _pid} = start_supervised({DeviceId, config})

      device_id = DeviceId.get()
      assert device_id == existing_uuid
    end

    test "persists the same uuid across genserver restarts" do
      path = "device_id.txt"

      # First start - no file exists
      expect(FrameCore.FileSystemMock, :read, fn ^path ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, fn ^path, _content ->
        :ok
      end)

      config = %DeviceId.Config{
        file_system: FrameCore.FileSystemMock
      }

      {:ok, pid} = DeviceId.start_link(config)
      first_id = DeviceId.get()

      GenServer.stop(pid)

      # Second start - file exists with the generated UUID
      expect(FrameCore.FileSystemMock, :read, fn ^path ->
        {:ok, first_id}
      end)

      {:ok, _pid} = DeviceId.start_link(config)
      second_id = DeviceId.get()

      assert first_id == second_id
    end

    test "handles file write errors gracefully" do
      path = "device_id.txt"

      expect(FrameCore.FileSystemMock, :read, fn ^path ->
        {:error, :enoent}
      end)

      expect(FrameCore.FileSystemMock, :write!, fn ^path, _content ->
        raise File.Error, reason: :eacces, action: "write", path: path
      end)

      config = %DeviceId.Config{
        file_system: FrameCore.FileSystemMock
      }

      result = start_supervised({DeviceId, config})

      assert {:error,
              {{:device_id_write_failed,
                %File.Error{reason: :eacces, action: "write", path: ^path}}, _child}} = result
    end

    test "fails fast when device id file cannot be read" do
      path = "device_id.txt"

      expect(FrameCore.FileSystemMock, :read, fn ^path ->
        {:error, :eacces}
      end)

      config = %DeviceId.Config{
        file_system: FrameCore.FileSystemMock
      }

      assert {:error, {{:device_id_read_failed, :eacces}, _child}} =
               start_supervised({DeviceId, config})
    end
  end
end
