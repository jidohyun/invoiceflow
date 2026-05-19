defmodule AutoMyInvoiceWeb.PaddleWebhookController do
  use AutoMyInvoiceWeb, :controller

  require Logger

  alias AutoMyInvoice.Payments
  alias AutoMyInvoice.Billing

  # AMI-14: Paddle docs recommend rejecting webhooks whose `ts` is more
  # than 5 seconds skew, but the worker process can be paused for GC or
  # rate-limited by the upstream proxy. We widen to 5 minutes which is
  # the standard tolerance most payment platforms use.
  @max_timestamp_skew_seconds 5 * 60

  @doc """
  POST /api/webhooks/paddle

  Receives Paddle Billing webhook events.
  Verifies HMAC-SHA256 signature, the timestamp window (replay
  protection), logs the event, and processes it.
  """
  def handle(conn, params) do
    with :ok <- verify_signature(conn),
         {:ok, event} <- log_event(params) do
      process_event(event, params)

      conn
      |> put_status(200)
      |> json(%{status: "ok"})
    else
      {:error, :invalid_signature} ->
        Logger.warning("Paddle webhook rejected — invalid signature")
        conn |> put_status(403) |> json(%{error: "Invalid signature"})

      {:error, :timestamp_outside_window} ->
        Logger.warning("Paddle webhook rejected — timestamp outside #{@max_timestamp_skew_seconds}s window")
        conn |> put_status(403) |> json(%{error: "Timestamp outside window"})

      {:error, :secret_missing_in_prod} ->
        Logger.error("Paddle webhook hit prod with no PADDLE_WEBHOOK_SECRET configured")
        conn |> put_status(500) |> json(%{error: "Webhook misconfigured"})

      {:error, :duplicate_event} ->
        conn |> put_status(200) |> json(%{status: "already_processed"})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: inspect(reason)})
    end
  end

  defp verify_signature(conn) do
    secret = Application.get_env(:auto_my_invoice, :paddle_webhook_secret)

    cond do
      is_binary(secret) and secret != "" ->
        signature = get_req_header(conn, "paddle-signature") |> List.first()
        verify_paddle_signature(conn, signature, secret)

      Application.get_env(:auto_my_invoice, :env) == :prod ->
        # Boot-time defensive guard. We never accept anonymous Paddle
        # callbacks in production — a misconfigured secret would mean
        # any attacker can call /api/webhooks/paddle and trigger
        # `subscription.created` / `transaction.completed` flows.
        {:error, :secret_missing_in_prod}

      true ->
        # dev/test convenience — let local test harnesses POST raw
        # payloads without hand-signing.
        :ok
    end
  end

  defp verify_paddle_signature(_conn, nil, _secret), do: {:error, :invalid_signature}

  defp verify_paddle_signature(conn, signature_header, secret) do
    # Paddle signature format: ts=TIMESTAMP;h1=HASH
    parts =
      signature_header
      |> String.split(";")
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Map.new(fn
        [k, v] -> {k, v}
        [k] -> {k, ""}
      end)

    ts = Map.get(parts, "ts", "")
    h1 = Map.get(parts, "h1", "")

    cond do
      ts == "" or h1 == "" ->
        {:error, :invalid_signature}

      not within_window?(ts) ->
        {:error, :timestamp_outside_window}

      true ->
        compare_hmac(conn, secret, ts, h1)
    end
  end

  defp compare_hmac(conn, secret, ts, h1) do
    raw_body = conn.assigns[:raw_body] || ""
    signed_payload = "#{ts}:#{raw_body}"

    expected =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(expected, h1) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp within_window?(ts) do
    case Integer.parse(ts) do
      {ts_int, ""} ->
        now = System.system_time(:second)
        abs(now - ts_int) <= @max_timestamp_skew_seconds

      _ ->
        false
    end
  end

  defp log_event(params) do
    event_id = params["event_id"] || Ecto.UUID.generate()
    event_type = params["event_type"] || "unknown"

    # Idempotency check
    case Payments.get_webhook_event(event_id) do
      nil ->
        case Payments.log_webhook_event(%{
               event_id: event_id,
               event_type: event_type,
               payload: params
             }) do
          {:ok, event} -> {:ok, event}
          {:error, _} -> {:error, :duplicate_event}
        end

      _existing ->
        {:error, :duplicate_event}
    end
  end

  defp process_event(event, params) do
    result =
      case params["event_type"] do
        "transaction.completed" ->
          Payments.process_transaction_completed(params["data"] || %{})

        "subscription.created" ->
          Billing.activate_subscription(params["data"] || %{})

        "subscription.updated" ->
          Billing.update_subscription(params["data"] || %{})

        "subscription.canceled" ->
          Billing.cancel_subscription(params["data"] || %{})

        _ ->
          :ok
      end

    case result do
      :ok ->
        Payments.mark_event_processed(event)

      {:error, reason} ->
        Payments.mark_event_failed(event, inspect(reason))
    end
  end
end
