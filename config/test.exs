import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix_test, :endpoint, PrimeYouthWeb.Endpoint

# Configure your database
#

# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# In test we don't send emails
# The MIX_TEST_PARTITION environment variable can be used

config :prime_youth, PrimeYouth.Mailer, adapter: Swoosh.Adapters.Test

config :prime_youth, PrimeYouth.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "prime_youth_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
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
  child_name_resolver: PrimeYouth.Attendance.Adapters.Driven.FamilyContext.ChildNameResolver

# Use test event publisher for testing
config :prime_youth, :event_publisher,
  module: PrimeYouth.Shared.Adapters.Driven.Events.TestEventPublisher,
  pubsub: PrimeYouth.PubSub

config :prime_youth, :family,
  child_repository: PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepository

# Repository configurations for test environment
config :prime_youth, :parenting,
  parent_repository:
    PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepository

config :prime_youth, :providing,
  provider_repository:
    PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepository

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
