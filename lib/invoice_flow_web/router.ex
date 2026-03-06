defmodule InvoiceFlowWeb.Router do
  use InvoiceFlowWeb, :router

  import InvoiceFlowWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {InvoiceFlowWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug InvoiceFlowWeb.Plugs.ApiAuth
  end

  # Public API routes (no auth required)
  scope "/api/v1", InvoiceFlowWeb.Api do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/google", AuthController, :google
  end

  # Authenticated API routes
  scope "/api/v1", InvoiceFlowWeb.Api do
    pipe_through :api_auth

    # Auth
    post "/auth/refresh", AuthController, :refresh
    delete "/auth/logout", AuthController, :logout

    # Dashboard
    get "/dashboard", DashboardController, :index
    get "/dashboard/recent", DashboardController, :recent

    # Invoices
    resources "/invoices", InvoiceController, except: [:new, :edit]
    post "/invoices/:id/send", InvoiceController, :send_invoice
    post "/invoices/:id/mark_paid", InvoiceController, :mark_paid

    # Clients
    resources "/clients", ClientController, except: [:new, :edit]

    # Upload & Extraction
    post "/upload", UploadController, :create
    get "/extraction/:id", UploadController, :show

    # Settings
    get "/settings", SettingsController, :show
    put "/settings", SettingsController, :update
  end

  # Public landing page (no auth required)
  scope "/", InvoiceFlowWeb do
    pipe_through :browser

    get "/welcome", PageController, :home
  end

  # Public routes (redirect if already authenticated)
  scope "/", InvoiceFlowWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{InvoiceFlowWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive
      live "/users/log_in", UserLoginLive
      live "/users/reset_password", UserForgotPasswordLive
    end

    post "/users/log_in", UserSessionController, :create
    get "/auth/google", UserOauthController, :request
    get "/auth/google/callback", UserOauthController, :callback
  end

  # Authenticated app routes
  scope "/", InvoiceFlowWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      layout: {InvoiceFlowWeb.Layouts, :app},
      on_mount: [{InvoiceFlowWeb.UserAuth, :ensure_authenticated}] do
      live "/", DashboardLive
      live "/invoices", InvoiceLive.Index
      live "/invoices/new", InvoiceLive.New
      live "/invoices/:id", InvoiceLive.Show
      live "/invoices/:id/edit", InvoiceLive.Edit
      live "/clients", ClientLive.Index
      live "/clients/new", ClientLive.New
      live "/clients/:id", ClientLive.Show
      live "/clients/:id/edit", ClientLive.Edit
      live "/upload", UploadLive
      live "/settings", UserSettingsLive
    end

    delete "/users/log_out", UserSessionController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:invoice_flow, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: InvoiceFlowWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
