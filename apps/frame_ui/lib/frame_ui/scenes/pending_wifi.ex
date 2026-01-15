defmodule FrameUI.Scenes.PendingWifi do
  @moduledoc """
  Scene for when there is no wifi configuration. Just displays a QR code to connect to the device's AP mode SSID.
  """

  alias Scenic.Graph
  alias Scenic.Primitive
  alias Scenic.Primitives

  @margin 20
  @cell_size 10

  @spec build_graph(Scenic.Scene.t(), String.t() | nil) :: Scenic.Graph.t()
  @doc """
  Given the scene, builds a graph displaying the QR code in the center, based on the scene's viewport size.
  """
  def build_graph(%{viewport: %{size: {width, height}}} = scene, ssid) do
    qr_input = "WIFI:T:nopass;S:#{escape_ssid(ssid)};P:;H:false;;"

    {:ok, qr} = QRCode.create(qr_input, :high)

    # qr.matrix, eg [[0,0,1,1,0,...], [0,1,1,0,0...]] where 1 is black, 0 is white
    qr_code_size = length(hd(qr.matrix)) * @cell_size
    # work out how to center the QR code
    qr_code_transform = {width / 2 - qr_code_size / 2, height / 2 - qr_code_size / 2}

    scene.assigns.graph
    |> Graph.modify(
      :main_group,
      fn group ->
        # first we're just clearing the group of whatever was there before
        Primitive.put(group, [])
      end
    )
    |> Graph.add_to(:main_group, fn graph ->
      graph
      |> Primitives.text("Pending WiFi Configuration", translate: {@margin, @margin}, fill: :red)
      |> Primitives.add_specs_to_graph([
        Primitives.group_spec_r([t: qr_code_transform], create_qr_code(qr.matrix, 0, []))
      ])
    end)
  end

  @spec create_qr_code([[integer()]], integer(), [Graph.deferred()]) :: [Graph.deferred()]
  defp create_qr_code([], _index, specs), do: specs

  defp create_qr_code([row | rows], index, specs) do
    specs = create_qr_code_cell(row, index, 0, specs)

    create_qr_code(rows, index + 1, specs)
  end

  @spec create_qr_code_cell([integer()], integer(), integer(), [Graph.deferred()]) :: [Graph.deferred()]
  defp create_qr_code_cell([], _row_index, _column_index, specs), do: specs

  defp create_qr_code_cell([cell | cells], row_index, column_index, specs) do
    color = if cell == 1, do: :black, else: :white

    spec =
      Primitives.rect_spec({@cell_size, @cell_size},
        fill: color,
        stroke: {1, color},
        translate: {column_index * @cell_size, row_index * @cell_size}
      )

    create_qr_code_cell(cells, row_index, column_index + 1, [spec | specs])
  end

  @spec escape_ssid(String.t()) :: String.t()
  defp escape_ssid(ssid) do
    ssid
    |> String.replace("\\", "\\\\")
    |> String.replace(";", "\\;")
    |> String.replace(",", "\\,")
    |> String.replace(":", "\\:")
    |> String.replace("\"", "\\\"")
  end
end
