defmodule InvoiceFlowWeb.InvoiceLive.Show do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.{Invoices, Reminders, PubSubTopics}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, PubSubTopics.invoice_updated(id))
    end

    reminders = Reminders.list_reminders_for_invoice(id)

    {:ok,
     socket
     |> assign(:page_title, invoice.invoice_number)
     |> assign(:invoice, invoice)
     |> assign(:reminders, reminders)}
  end

  @impl true
  def handle_event("send", _params, socket) do
    case Invoices.send_invoice(socket.assigns.invoice) do
      {:ok, invoice} ->
        reminders = Reminders.list_reminders_for_invoice(invoice.id)

        {:noreply,
         socket
         |> assign(:invoice, invoice)
         |> assign(:reminders, reminders)
         |> put_flash(:info, "Invoice sent successfully")}

      {:error, :not_draft} ->
        {:noreply, put_flash(socket, :error, "Only draft invoices can be sent")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not send invoice")}
    end
  end

  @impl true
  def handle_event("mark_paid", _params, socket) do
    case Invoices.mark_as_paid(socket.assigns.invoice) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> assign(:invoice, invoice)
         |> put_flash(:info, "Invoice marked as paid")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not mark as paid")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Invoices.delete_invoice(socket.assigns.invoice) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invoice deleted")
         |> push_navigate(to: ~p"/invoices")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete invoice")}
    end
  end

  @impl true
  def handle_info({:invoice_updated, invoice}, socket) do
    reminders = Reminders.list_reminders_for_invoice(invoice.id)

    {:noreply,
     socket
     |> assign(:invoice, invoice)
     |> assign(:reminders, reminders)}
  end

  defp status_actions(status) do
    case status do
      "draft" -> [:send, :edit, :delete]
      "sent" -> [:mark_paid]
      "overdue" -> [:mark_paid]
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :actions, status_actions(assigns.invoice.status))

    ~H"""
    <.page_header title={@invoice.invoice_number}>
      <:actions>
        <.link :if={:edit in @actions} navigate={~p"/invoices/#{@invoice.id}/edit"} class="btn btn-ghost btn-sm">
          <.icon name="hero-pencil" class="size-4" /> Edit
        </.link>
        <button :if={:send in @actions} class="btn btn-info btn-sm" phx-click="send" data-confirm="Send this invoice?">
          <.icon name="hero-paper-airplane" class="size-4" /> Send
        </button>
        <button :if={:mark_paid in @actions} class="btn btn-success btn-sm" phx-click="mark_paid" data-confirm="Mark as paid?">
          <.icon name="hero-check-circle" class="size-4" /> Mark Paid
        </button>
        <button :if={:delete in @actions} class="btn btn-error btn-sm" phx-click="delete" data-confirm="Delete this invoice?">
          <.icon name="hero-trash" class="size-4" /> Delete
        </button>
        <.link navigate={~p"/invoices"} class="btn btn-ghost btn-sm">← Back</.link>
      </:actions>
    </.page_header>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
      <div class="card bg-base-100 shadow lg:col-span-2">
        <div class="card-body">
          <h2 class="card-title text-lg">Invoice Details</h2>
          <div class="grid grid-cols-2 gap-4 mt-2">
            <div>
              <span class="text-sm text-base-content/60">Client</span>
              <p>
                <%= if @invoice.client do %>
                  <.link navigate={~p"/clients/#{@invoice.client.id}"} class="link link-primary">
                    {@invoice.client.name}
                  </.link>
                <% else %>
                  -
                <% end %>
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Status</span>
              <p><.status_badge status={@invoice.status} /></p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Amount</span>
              <p class="text-xl font-bold"><.money amount={@invoice.amount} currency={@invoice.currency} /></p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Due Date</span>
              <p><.date_display date={@invoice.due_date} /></p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Created</span>
              <p><.date_display date={@invoice.inserted_at} format="short" /></p>
            </div>
            <div :if={@invoice.sent_at}>
              <span class="text-sm text-base-content/60">Sent</span>
              <p><.date_display date={@invoice.sent_at} format="short" /></p>
            </div>
            <div :if={@invoice.paid_at}>
              <span class="text-sm text-base-content/60">Paid</span>
              <p><.date_display date={@invoice.paid_at} format="short" /></p>
            </div>
          </div>
          <div :if={@invoice.notes} class="mt-4">
            <span class="text-sm text-base-content/60">Notes</span>
            <p class="whitespace-pre-wrap">{@invoice.notes}</p>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">Payment Summary</h2>
          <div class="space-y-3 mt-2">
            <div>
              <span class="text-sm text-base-content/60">Total</span>
              <p class="text-xl font-bold"><.money amount={@invoice.amount} currency={@invoice.currency} /></p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Paid</span>
              <p class="text-xl font-bold text-success">
                <.money amount={@invoice.paid_amount || Decimal.new(0)} currency={@invoice.currency} />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Remaining</span>
              <p class="text-xl font-bold text-warning">
                <.money
                  amount={Decimal.sub(@invoice.amount || Decimal.new(0), @invoice.paid_amount || Decimal.new(0))}
                  currency={@invoice.currency}
                />
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card bg-base-100 shadow mb-6">
      <div class="card-body">
        <h2 class="card-title text-lg">Line Items</h2>
        <%= if @invoice.items == [] do %>
          <p class="text-base-content/60 mt-2">No line items</p>
        <% else %>
          <div class="overflow-x-auto mt-2">
            <table class="table">
              <thead>
                <tr>
                  <th>Description</th>
                  <th class="text-right">Qty</th>
                  <th class="text-right">Unit Price</th>
                  <th class="text-right">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={item <- @invoice.items}>
                  <td>{item.description}</td>
                  <td class="text-right">{item.quantity}</td>
                  <td class="text-right"><.money amount={item.unit_price} currency={@invoice.currency} /></td>
                  <td class="text-right font-medium"><.money amount={item.total} currency={@invoice.currency} /></td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="font-bold">
                  <td colspan="3" class="text-right">Total</td>
                  <td class="text-right"><.money amount={@invoice.amount} currency={@invoice.currency} /></td>
                </tr>
              </tfoot>
            </table>
          </div>
        <% end %>
      </div>
    </div>

    <div :if={@reminders != []} class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title text-lg">Reminder Timeline</h2>
        <.timeline>
          <:item
            :for={r <- @reminders}
            title={"Step #{r.step} Reminder"}
            description={status_text(r)}
            datetime={format_reminder_time(r)}
            status={to_string(reminder_status(r))}
          />
        </.timeline>
      </div>
    </div>
    """
  end

  defp format_reminder_time(r) do
    dt = r.scheduled_at || r.sent_at || r.inserted_at
    if dt, do: Calendar.strftime(dt, "%b %d, %Y"), else: "-"
  end

  defp status_text(reminder) do
    case reminder.status do
      "pending" -> "Scheduled"
      "scheduled" -> "Queued for delivery"
      "sent" -> "Delivered"
      "opened" -> "Opened by recipient"
      "clicked" -> "Link clicked"
      "failed" -> "Delivery failed"
      "cancelled" -> "Cancelled"
      _ -> reminder.status
    end
  end

  defp reminder_status(reminder) do
    case reminder.status do
      s when s in ~w(sent opened clicked) -> :complete
      s when s in ~w(pending scheduled) -> :pending
      _ -> :error
    end
  end
end
