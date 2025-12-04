System.put_env("BACKEND_URL", "http://localhost:4000")

# Silence logger output during tests
Logger.configure(level: :error)

ExUnit.start(colors: [enabled: true], trace: true)

Mox.defmock(FrameCore.FileSystemMock, for: FrameCore.FileSystem)
Mox.defmock(FrameCore.HttpClientMock, for: FrameCore.HttpClient)
