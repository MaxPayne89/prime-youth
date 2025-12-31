import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Print only warnings and errors during test
config :logger, level: :warning

# OpenTelemetry: disable tracing in tests for performance
config :opentelemetry, traces_exporter: :none

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure your database

# Enable helpful, but potentially expensive runtime checks
#

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# In test we don't send emails
# The MIX_TEST_PARTITION environment variable can be used
# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phoenix_test, :endpoint, PrimeYouthWeb.Endpoint

config :prime_youth, PrimeYouth.Mailer, adapter: Swoosh.Adapters.Test

config :prime_youth, PrimeYouth.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "prime_youth_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :prime_youth, PrimeYouthWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gY/oKuAYeC5ExhHrtu1JBwrpQdoGwtPOo3X9GdS7CFOnLe0eqRQ9w4cyV1MqvoYc",
  server: false

config :prime_youth, :attendance,
  session_repository:
    PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.SessionRepository,
  attendance_repository:
    PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.AttendanceRepository,
  child_name_resolver: PrimeYouth.Attendance.Adapters.Driven.IdentityContext.ChildNameResolver

# Use test event publisher for testing
config :prime_youth, :event_publisher,
  module: PrimeYouth.Shared.Adapters.Driven.Events.TestEventPublisher,
  pubsub: PrimeYouth.PubSub

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
