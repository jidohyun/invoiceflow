defmodule AutoMyInvoice.QR do
  @moduledoc """
  Tiny wrapper around `:eqrcode` so the rest of the app never has to
  remember which encode/render call to chain.

  All three outputs (PNG bytes, SVG string, data URL) share the same
  underlying QR matrix — pick whichever the caller can embed cheapest.
  """

  @doc "Render `text` as PNG bytes. Returns a binary you can stream or save."
  @spec to_png(String.t()) :: binary()
  def to_png(text) when is_binary(text) do
    text
    |> EQRCode.encode()
    |> EQRCode.png()
  end

  @doc "Render `text` as an inline SVG string."
  @spec to_svg(String.t()) :: String.t()
  def to_svg(text) when is_binary(text) do
    text
    |> EQRCode.encode()
    |> EQRCode.svg()
  end

  @doc """
  Render `text` as a base64 `data:image/png` URL suitable for `<img src=…>`.
  Used by the LiveView "instant invoice" screen.
  """
  @spec to_data_url(String.t()) :: String.t()
  def to_data_url(text) when is_binary(text) do
    "data:image/png;base64," <> Base.encode64(to_png(text))
  end
end
