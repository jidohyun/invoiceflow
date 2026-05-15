defmodule AutoMyInvoice.Billing.PaddleClient do
  @moduledoc """
  Paddle Billing API v2 client.
  Creates transactions with checkout URLs for invoice payments.
  """

  @base_url "https://api.paddle.com"
  @sandbox_url "https://sandbox-api.paddle.com"

  @spec create_payment_link(map()) :: {:ok, String.t()} | {:error, String.t()}
  def create_payment_link(%{invoice: invoice, client: client}) do
    api_key = Application.get_env(:auto_my_invoice, :paddle_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, "PADDLE_API_KEY not configured"}
    else
      do_create_payment_link(invoice, client, api_key)
    end
  end

  defp do_create_payment_link(invoice, client, api_key) do
    body = %{
      items: [
        %{
          price: %{
            description: "Invoice #{invoice.invoice_number}",
            name: "Invoice Payment",
            unit_price: %{
              amount: amount_to_cents(invoice.amount),
              currency_code: String.downcase(invoice.currency)
            },
            product: %{
              name: "Invoice #{invoice.invoice_number}",
              description: "Payment for invoice #{invoice.invoice_number}"
            }
          },
          quantity: 1
        }
      ],
      customer: %{
        email: client.email,
        name: client.name
      },
      custom_data: %{
        invoice_id: invoice.id
      },
      checkout: %{
        url: checkout_return_url()
      }
    }

    case Req.post(base_url() <> "/transactions",
           json: body,
           headers: [{"authorization", "Bearer #{api_key}"}],
           receive_timeout: 30_000
         ) do
      {:ok, %{status: status, body: %{"data" => data}}} when status in [200, 201] ->
        checkout_url = get_in(data, ["checkout", "url"]) || ""
        {:ok, checkout_url}

      {:ok, %{status: status, body: body}} ->
        {:error, "Paddle API error (#{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp amount_to_cents(%Decimal{} = amount) do
    amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_string(:normal)
  end

  defp base_url do
    if Application.get_env(:auto_my_invoice, :paddle_sandbox, true) do
      @sandbox_url
    else
      @base_url
    end
  end

  defp checkout_return_url do
    Application.get_env(
      :auto_my_invoice,
      :paddle_checkout_return_url,
      "https://automyinvoice.app/payment/success"
    )
  end
end
