defmodule InvoiceFlowWeb.Api.JsonHelpers do
  @moduledoc "Shared JSON serialization helpers for API controllers."

  def render_invoice(invoice) do
    %{
      id: invoice.id,
      invoice_number: invoice.invoice_number,
      status: invoice.status,
      amount: invoice.amount,
      paid_amount: invoice.paid_amount,
      currency: invoice.currency,
      due_date: invoice.due_date,
      sent_at: invoice.sent_at,
      paid_at: invoice.paid_at,
      notes: invoice.notes,
      client_id: invoice.client_id,
      client: if(Ecto.assoc_loaded?(invoice.client) && invoice.client, do: render_client(invoice.client)),
      items: if(Ecto.assoc_loaded?(invoice.items), do: Enum.map(invoice.items, &render_item/1), else: []),
      inserted_at: invoice.inserted_at,
      updated_at: invoice.updated_at
    }
  end

  def render_client(client) do
    %{
      id: client.id,
      name: client.name,
      email: client.email,
      company: client.company,
      phone: client.phone,
      address: client.address,
      inserted_at: client.inserted_at,
      updated_at: client.updated_at
    }
  end

  def render_item(item) do
    %{
      id: item.id,
      description: item.description,
      quantity: item.quantity,
      unit_price: item.unit_price,
      position: item.position
    }
  end

  def render_user(user) do
    %{
      id: user.id,
      email: user.email,
      company_name: user.company_name,
      plan: user.plan,
      timezone: user.timezone,
      brand_tone: user.brand_tone,
      avatar_url: user.avatar_url,
      inserted_at: user.inserted_at
    }
  end

  def render_extraction_job(job) do
    %{
      id: job.id,
      status: job.status,
      original_filename: job.original_filename,
      confidence_score: job.confidence_score,
      extracted_data: job.extracted_data,
      error_message: job.error_message,
      inserted_at: job.inserted_at
    }
  end

  def changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
