import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :klass_hero, KlassHero.Mailer, adapter: Swoosh.Adapters.Test

config :klass_hero, KlassHero.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "klass_hero_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :klass_hero, KlassHeroWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gY/oKuAYeC5ExhHrtu1JBwrpQdoGwtPOo3X9GdS7CFOnLe0eqRQ9w4cyV1MqvoYc",
  server: false

# Oban: disable in tests, use inline testing mode
# Use test event publisher for testing
config :klass_hero, Oban, testing: :inline

config :klass_hero, :event_publisher,
  module: KlassHero.Shared.Adapters.Driven.Events.TestEventPublisher,
  pubsub: KlassHero.PubSub

config :klass_hero, :integration_event_publisher,
  module: KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher,
  pubsub: KlassHero.PubSub

config :klass_hero, :participation,
  session_repository:
    KlassHero.Participation.Adapters.Driven.Persistence.Repositories.SessionRepository,
  participation_repository:
    KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository,
  child_info_resolver: KlassHero.Participation.Adapters.Driven.IdentityContext.ChildInfoResolver,
  behavioral_note_repository:
    KlassHero.Participation.Adapters.Driven.Persistence.Repositories.BehavioralNoteRepository

# Use stub adapter for tests by default
config :klass_hero, :storage,
  adapter: KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter,
  public_bucket: "test-public",
  private_bucket: "test-private"

# Print only warnings and errors during test
config :logger, level: :warning

# OpenTelemetry: disable tracing in tests for performance
config :opentelemetry, traces_exporter: :none

# Initialize plugs at runtime for faster test compilation
# Enable helpful, but potentially expensive runtime checks
#
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :phoenix, :plug_init_mode, :runtime

# Configure your database
# In test we don't send emails
# The MIX_TEST_PARTITION environment variable can be used
# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix_test, :endpoint, KlassHeroWeb.Endpoint

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
