import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
db_username = System.get_env("POSTGRES_USER") || System.get_env("USER") || "jidohyun"
db_password = System.get_env("POSTGRES_PASSWORD") || ""
db_hostname = System.get_env("POSTGRES_HOST") || "localhost"
db_port = String.to_integer(System.get_env("POSTGRES_PORT") || "5432")
# Test DB name does NOT fall back to POSTGRES_DB to prevent test runs from
# accidentally touching the dev database when both vars are set.
db_database =
  (System.get_env("TEST_POSTGRES_DB") || "auto_my_invoice_test") <>
    "#{System.get_env("MIX_TEST_PARTITION")}"

config :auto_my_invoice, AutoMyInvoice.Repo,
  username: db_username,
  password: db_password,
  hostname: db_hostname,
  port: db_port,
  database: db_database,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :auto_my_invoice, AutoMyInvoiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DoCLguvcgiQKibG2aS+MWTrUm9KjKuUw0II6+MmUbfeuPhIOmQ7Wt/sx9UwbAK8r",
  server: false

# In test we don't send emails
config :auto_my_invoice, AutoMyInvoice.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Configure Oban for test (inline execution, no queues)
config :auto_my_invoice, Oban, testing: :inline

# ChromicPDF: disable Chrome sandbox so tests can boot inside Docker (or any
# unprivileged container) without requiring a user-namespace sandbox profile.
config :auto_my_invoice, ChromicPDF, chrome_args: "--no-sandbox"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
