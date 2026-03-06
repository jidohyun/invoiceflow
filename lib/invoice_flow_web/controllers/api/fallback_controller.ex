defmodule InvoiceFlowWeb.Api.FallbackController do
  @moduledoc "Translates controller action results into API JSON responses."

  use InvoiceFlowWeb, :controller

  alias InvoiceFlowWeb.Api.JsonHelpers

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{
      code: "validation_error",
      message: "Invalid input",
      details: JsonHelpers.changeset_errors(changeset)
    }})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{code: "not_found", message: "Resource not found"}})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: %{code: "unauthorized", message: "Invalid credentials"}})
  end

  def call(conn, {:error, :not_draft}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "invalid_status", message: "Invoice must be in draft status"}})
  end

  def call(conn, {:error, :cannot_delete_non_draft}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "invalid_status", message: "Only draft invoices can be deleted"}})
  end

  def call(conn, {:error, :plan_limit}) do
    conn
    |> put_status(:payment_required)
    |> json(%{error: %{code: "plan_limit", message: "Monthly invoice limit reached. Upgrade your plan."}})
  end
end
