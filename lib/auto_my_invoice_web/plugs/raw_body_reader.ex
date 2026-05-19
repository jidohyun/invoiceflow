defmodule AutoMyInvoiceWeb.Plugs.RawBodyReader do
  @moduledoc """
  Custom body reader that caches the raw request body for webhook
  signature verification (AMI-14).

  Only attaches `conn.assigns[:raw_body]` for paths under
  `/api/webhooks/*`. Non-webhook paths get the default
  `Plug.Conn.read_body/2` behaviour — no extra memory cost.

  Usage in endpoint.ex:

      plug Plug.Parsers,
        ...,
        body_reader: {AutoMyInvoiceWeb.Plugs.RawBodyReader, :read_body, []}
  """

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, maybe_cache(conn, body)}

      {:more, body, conn} ->
        # Body too large for a single read — Plug.Parsers will call us
        # again. Cache what we have so far; signature verification will
        # fail on truncated payloads anyway, which is the safe outcome.
        {:more, body, maybe_cache(conn, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_cache(conn, body) do
    if webhook_path?(conn) do
      existing = conn.assigns[:raw_body] || ""
      Plug.Conn.assign(conn, :raw_body, existing <> body)
    else
      conn
    end
  end

  defp webhook_path?(%Plug.Conn{path_info: ["api", "webhooks" | _]}), do: true
  defp webhook_path?(_), do: false
end
