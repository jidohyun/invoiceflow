defmodule AutoMyInvoiceWeb.EmailTrackingController do
  use AutoMyInvoiceWeb, :controller

  alias AutoMyInvoice.Reminders

  @transparent_pixel Base.decode64!("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")

  @doc """
  GET /api/track/open/:reminder_id

  Returns a 1x1 transparent GIF pixel and records the email open.
  """
  def open(conn, %{"reminder_id" => reminder_id}) do
    case Reminders.record_open(reminder_id) do
      {:ok, _reminder} -> :ok
      _ -> :ok
    end

    conn
    |> put_resp_content_type("image/gif")
    |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
    |> send_resp(200, @transparent_pixel)
  end

  @doc """
  GET /api/track/click/:reminder_id

  Records the click and redirects to the invoice's payment link.
  """
  def click(conn, %{"reminder_id" => reminder_id}) do
    case Reminders.record_click(reminder_id) do
      {:ok, reminder} ->
        reminder = AutoMyInvoice.Repo.preload(reminder, :invoice)
        payment_link = Map.get(reminder.invoice, :paddle_payment_link)

        if payment_link do
          redirect(conn, external: payment_link)
        else
          conn
          |> put_status(404)
          |> json(%{error: "Payment link not available"})
        end

      _ ->
        conn
        |> put_status(404)
        |> json(%{error: "Reminder not found"})
    end
  end
end
