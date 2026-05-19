defmodule AutoMyInvoice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AutoMyInvoiceWeb.Telemetry,
      AutoMyInvoice.Repo,
      {DNSCluster, query: Application.get_env(:auto_my_invoice, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AutoMyInvoice.PubSub},
      {Cachex, name: :auto_my_invoice_cache},
      # AMI-15: ETS-backed rate limiter — single ETS table shared by all
      # rate-limit keys (per-user API, per-IP auth).
      AutoMyInvoice.RateLimiter,
      # AMI-19: HTTP client for Sentry.FinchClient. Stays up even when
      # SENTRY_DSN is unset — the Sentry client just no-ops on send.
      {Finch, name: Sentry.Finch},
      {Oban, Application.fetch_env!(:auto_my_invoice, Oban)},
      {ChromicPDF, Application.get_env(:auto_my_invoice, ChromicPDF, [])},
      AutoMyInvoiceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AutoMyInvoice.Supervisor]
    result = Supervisor.start_link(children, opts)

    # AMI-19: attach Sentry as an Elixir Logger handler so any
    # Logger.error/warning from controllers, workers, or LiveViews
    # is captured. We only attach when SENTRY_DSN is configured —
    # otherwise the handler logs noisy "missing DSN" warnings on
    # every event in dev/test.
    if Application.get_env(:sentry, :dsn) do
      :ok = :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{})
    end

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AutoMyInvoiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
