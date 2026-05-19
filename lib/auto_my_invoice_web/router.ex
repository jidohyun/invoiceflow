defmodule AutoMyInvoiceWeb.Router do
  use AutoMyInvoiceWeb, :router

  import AutoMyInvoiceWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AutoMyInvoiceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    # AMI-20: CORS for /api/v1 + /api/webhooks (no harm on webhooks since
    # third parties don't run JS). Origins are taken from `:cors_origins`
    # in Application env — see config/runtime.exs for the env-var wiring.
    plug Corsica,
      origins: {AutoMyInvoiceWeb.Cors, :allowed_origins, []},
      allow_credentials: true,
      allow_headers: ["authorization", "content-type", "accept", "x-requested-with"],
      max_age: 600,
      log: [rejected: :warn]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
plug AutoMyInvoiceWeb.Plugs.ApiAuth
  end

  # Webhook routes (no CSRF, no auth)
  scope "/api/webhooks", AutoMyInvoiceWeb do
    pipe_through :api

    post "/paddle", PaddleWebhookController, :handle
  end

  # Email tracking routes (no auth, public for email clients)
  scope "/api/track", AutoMyInvoiceWeb do
    pipe_through :api

    get "/open/:reminder_id", EmailTrackingController, :open
    get "/click/:reminder_id", EmailTrackingController, :click
  end

  # Public API routes (no auth required)
  scope "/api/v1", AutoMyInvoiceWeb.Api do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/google", AuthController, :google
  end

  # Authenticated API routes
  scope "/api/v1", AutoMyInvoiceWeb.Api do
    pipe_through :api_auth

    # Auth
    post "/auth/refresh", AuthController, :refresh
    delete "/auth/logout", AuthController, :logout

    # Dashboard
    get "/dashboard", DashboardController, :index
    get "/dashboard/recent", DashboardController, :recent
    get "/dashboard/analytics", AnalyticsController, :dashboard
    get "/dashboard/cashflow", AnalyticsController, :cashflow

    # Invoices
    resources "/invoices", InvoiceController, except: [:new, :edit]
    post "/invoices/:id/send", InvoiceController, :send_invoice
    post "/invoices/:id/mark_paid", InvoiceController, :mark_paid
    post "/invoices/:id/record_payment", InvoiceController, :record_payment
    post "/invoices/:id/send_reminder", InvoiceController, :send_reminder

    # Client Analytics (ranking must come before :id routes)
    get "/clients/ranking", ClientAnalyticsController, :ranking
    get "/clients/:id/analytics", ClientAnalyticsController, :show

    # Clients
    resources "/clients", ClientController, except: [:new, :edit]

    # Analytics
    get "/analytics/reminders", ReminderAnalyticsController, :index

    # Upload & Extraction
    post "/upload", UploadController, :create
    get "/extraction/:id", UploadController, :show

    # Settings
    get "/settings", SettingsController, :show
    put "/settings", SettingsController, :update
  end

  # Public landing page (no auth required)
  scope "/", AutoMyInvoiceWeb do
    pipe_through :browser

    get "/welcome", PageController, :home
    # AMI-17: load-balancer health probe — plain HTTP, excluded from
    # force_ssl in config/prod.exs.
    get "/health", PageController, :health
    # AMI-89: public scan-to-pay landing — opens from a QR shown on the
    # merchant's phone, no login required for the customer.
    live "/pay/:id", PayLive
  end

  # Public routes (redirect if already authenticated)
  scope "/", AutoMyInvoiceWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{AutoMyInvoiceWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive
      live "/users/log_in", UserLoginLive
      live "/users/reset_password", UserForgotPasswordLive
      live "/users/reset_password/:token", UserResetPasswordLive
    end

    post "/users/log_in", UserSessionController, :create
    get "/auth/google", UserOauthController, :request
    get "/auth/google/callback", UserOauthController, :callback
  end

  # Authenticated app routes
  scope "/", AutoMyInvoiceWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      layout: {AutoMyInvoiceWeb.Layouts, :app},
      on_mount: [{AutoMyInvoiceWeb.UserAuth, :ensure_authenticated}] do
      live "/", DashboardLive
      live "/invoices", InvoiceLive.Index
      live "/invoices/new", InvoiceLive.New
      live "/invoices/quick", InvoiceLive.Quick
      live "/invoices/:id", InvoiceLive.Show
      live "/invoices/:id/edit", InvoiceLive.Edit
      live "/clients", ClientLive.Index
      live "/clients/new", ClientLive.New
      live "/clients/:id", ClientLive.Show
      live "/clients/:id/edit", ClientLive.Edit
      live "/analytics", AnalyticsLive
      live "/upload", UploadLive
      live "/settings", UserSettingsLive
      live "/settings/billing", BillingLive
    end

    get "/invoices/:id/pdf", InvoicePDFController, :download
    delete "/users/log_out", UserSessionController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:auto_my_invoice, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AutoMyInvoiceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
