defmodule AutoMyInvoiceWeb.Plugs.RateLimit do
  @moduledoc """
  AMI-15 — token bucket rate limit plug.

  Two opts:

    * `:scale_ms`  — bucket window in milliseconds (default 60_000)
    * `:limit`     — max requests per window (default 60)
    * `:bucket`    — :user (authenticated, key = user.id) or
                     :ip   (anonymous, key = remote IP)
    * `:name`      — fixed prefix for the bucket key, distinguishes
                     /auth/login from /auth/register etc.

  Refuses with 429 + `Retry-After` header + JSON body when over the
  limit. Bucket state lives in `AutoMyInvoice.RateLimiter` (ETS).

  Disabled in :test by default so the suite stays deterministic;
  override with `Application.put_env(:auto_my_invoice, :rate_limit_enabled, true)`
  inside a test that needs to exercise the plug.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    if enabled?() do
      do_call(conn, opts)
    else
      conn
    end
  end

  defp do_call(conn, opts) do
    scale = Keyword.get(opts, :scale_ms, 60_000)
    limit = Keyword.get(opts, :limit, 60)
    bucket = Keyword.fetch!(opts, :bucket)
    name = Keyword.fetch!(opts, :name)

    key = build_key(bucket, name, conn)

    case AutoMyInvoice.RateLimiter.hit(key, scale, limit) do
      {:allow, _count} ->
        conn

      {:deny, retry_ms} ->
        retry_after_s = max(div(retry_ms, 1000), 1)

        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after_s))
        |> put_resp_content_type("application/json")
        |> send_resp(
          429,
          Jason.encode!(%{
            error: "rate_limited",
            retry_after_seconds: retry_after_s
          })
        )
        |> halt()
    end
  end

  defp build_key(:user, name, conn) do
    user_id =
      case conn.assigns[:current_user] do
        %{id: id} -> id
        _ -> "anon"
      end

    "#{name}:user:#{user_id}"
  end

  defp build_key(:ip, name, conn) do
    "#{name}:ip:#{format_ip(conn.remote_ip)}"
  end

  defp format_ip(tuple) when is_tuple(tuple) do
    tuple |> :inet.ntoa() |> to_string()
  end

  defp enabled? do
    case Application.get_env(:auto_my_invoice, :rate_limit_enabled) do
      nil ->
        # Default: on everywhere except test.
        Application.get_env(:auto_my_invoice, :env) != :test

      explicit ->
        !!explicit
    end
  end
end
