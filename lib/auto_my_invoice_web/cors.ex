defmodule AutoMyInvoiceWeb.Cors do
  @moduledoc """
  AMI-20 — origin allow-list for /api/v1 + /api/webhooks.

  Source of truth is `Application.get_env(:auto_my_invoice, :cors_origins)`,
  which `config/runtime.exs` populates from `CORS_ALLOWED_ORIGINS` —
  a comma-separated list, e.g.:

      CORS_ALLOWED_ORIGINS=https://app.auto-my-invoice.com,https://admin.auto-my-invoice.com

  Defaults:
    * `:test` — `:self` (only same-origin, keeps tests deterministic)
    * `:dev`  — `"*"` (any origin, convenient for local mobile dev)
    * `:prod` — `:self` if the env var is unset, which is the conservative
      choice. Setting `CORS_ALLOWED_ORIGINS="*"` is supported but logged
      at boot as a warning.

  Corsica 2.x calls `matches?/1` per request, expecting a boolean,
  through the `{Module, :function}` form in its `:origins` list.
  """

  require Logger

  @spec allowed_origins() :: list() | :self | String.t()
  def allowed_origins do
    case Application.get_env(:auto_my_invoice, :cors_origins) do
      nil -> default_for_env()
      "" -> default_for_env()
      "*" -> wildcard()
      value when is_binary(value) -> parse_csv(value)
      value when is_list(value) -> value
    end
  end

  @doc """
  Corsica 2.x calls this with the actual Origin header value and
  expects a boolean. We resolve the allow-list on every request so
  live changes to `CORS_ALLOWED_ORIGINS` (and test put_env overrides)
  take effect without recompiling the Endpoint.
  """
  @spec matches?(String.t()) :: boolean()
  def matches?(actual_origin) when is_binary(actual_origin) do
    case allowed_origins() do
      "*" -> true
      :self -> false
      list when is_list(list) -> actual_origin in list
    end
  end

  def matches?(_), do: false

  defp parse_csv(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp wildcard do
    if Application.get_env(:auto_my_invoice, :env) == :prod do
      Logger.warning("CORS configured as '*' in :prod — any origin can call /api/v1")
    end

    "*"
  end

  defp default_for_env do
    case Application.get_env(:auto_my_invoice, :env) do
      :dev -> "*"
      _ -> :self
    end
  end
end
