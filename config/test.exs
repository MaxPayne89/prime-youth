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

# We don't run a server during test
config :klass_hero, KlassHeroWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gY/oKuAYeC5ExhHrtu1JBwrpQdoGwtPOo3X9GdS7CFOnLe0eqRQ9w4cyV1MqvoYc",
  server: false

# Oban runs inline in tests so critical event handlers execute synchronously
config :klass_hero, Oban, testing: :inline

# Use test event publishers for testing
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
  child_info_resolver: KlassHero.Participation.Adapters.Driven.FamilyContext.ChildInfoResolver,
  behavioral_note_repository:
    KlassHero.Participation.Adapters.Driven.Persistence.Repositories.BehavioralNoteRepository,
  # Use stub adapter for tests by default
  # Trigger: VerifiedProviders GenServer bootstraps a DB query at app startup
  # Why: that query runs outside the Ecto test sandbox, poisoning the connection pool
  # Outcome: disabling projections prevents sandbox leaks across async tests
  program_provider_resolver:
    KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolver,
  enrolled_children_resolver:
    KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver

config :klass_hero, :storage,
  # Trigger: webhook tests send plain JSON without real Svix signing infrastructure
  # Why: signature verification requires a live webhook secret and real headers
  # Outcome: VerifyWebhookSignature plug is a no-op in tests
  adapter: KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter,
  bucket: "klass-hero-test"

config :klass_hero, :verify_webhook_signature, false
config :klass_hero, env: :test
config :klass_hero, start_projections: false

# Print only warnings and errors during test
config :logger, level: :warning

# OpenTelemetry: disable tracing in tests for performance
config :opentelemetry, traces_exporter: :none

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix_test, :endpoint, KlassHeroWeb.Endpoint

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
