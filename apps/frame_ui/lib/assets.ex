defmodule FrameUI.Assets do
  @moduledoc """
  Static assets for the FrameUI application.
  """

  use Scenic.Assets.Static,
    otp_app: :frame_ui,
    alias: [
      roboto: "fonts/roboto.ttf",
      roboto_mono: "fonts/roboto_mono.ttf"
    ]
end
