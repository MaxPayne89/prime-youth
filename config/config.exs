# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :error_tracker, repo: KlassHero.Repo, otp_app: :klass_hero, enabled: true

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  klass_hero: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# Configures the endpoint
config :klass_hero, KlassHero.Mailer, adapter: Swoosh.Adapters.Local

config :klass_hero, KlassHeroWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KlassHeroWeb.ErrorHTML, json: KlassHeroWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: KlassHero.PubSub,
  live_view: [signing_salt: "JU2osypv"]

# Configure Gettext for internationalization
config :klass_hero, KlassHeroWeb.Gettext,
  default_locale: "en",
  locales: ~w(en de)

# Configure Oban for background jobs
config :klass_hero, Oban,
  repo: KlassHero.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", KlassHero.Messaging.Workers.MessageCleanupWorker},
       {"0 4 * * *", KlassHero.Messaging.Workers.RetentionPolicyWorker}
     ]}
  ],
  queues: [default: 10, messaging: 5, cleanup: 2]

# Configure Community bounded context
config :klass_hero, :community,
  repository: KlassHero.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository

# Configure Enrollment bounded context
config :klass_hero, :enrollment,
  for_managing_enrollments:
    KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository

# Configure Event Publisher (domain events — internal context communication)
config :klass_hero, :event_publisher,
  module: KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher,
  pubsub: KlassHero.PubSub

# Configure Identity bounded context
config :klass_hero, :identity,
  repo: KlassHero.Repo,
  for_storing_parent_profiles:
    KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ParentProfileRepository,
  for_storing_provider_profiles:
    KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository,
  for_storing_children:
    KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository,
  for_storing_consents:
    KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ConsentRepository

# Configure Integration Event Publisher (cross-context communication)
config :klass_hero, :integration_event_publisher,
  module: KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher,
  pubsub: KlassHero.PubSub

# Configure Messaging bounded context
config :klass_hero, :messaging,
  for_managing_conversations:
    KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationRepository,
  for_managing_messages:
    KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository,
  for_managing_participants:
    KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository,
  for_resolving_users: KlassHero.Messaging.Adapters.Driven.Accounts.UserResolver,
  for_querying_enrollments: KlassHero.Messaging.Adapters.Driven.Enrollment.EnrollmentResolver,
  retention: [
    days_after_program_end: 30,
    retention_period_days: 30
  ]

# Configure Participation bounded context
config :klass_hero, :participation,
  session_repository:
    KlassHero.Participation.Adapters.Driven.Persistence.Repositories.SessionRepository,
  participation_repository:
    KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository,
  child_info_resolver: KlassHero.Participation.Adapters.Driven.IdentityContext.ChildInfoResolver,
  behavioral_note_repository:
    KlassHero.Participation.Adapters.Driven.Persistence.Repositories.BehavioralNoteRepository

# Configure Program Catalog bounded context
config :klass_hero, :program_catalog,
  repository: KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository

config :klass_hero, :scopes,
  user: [
    default: true,
    module: KlassHero.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: KlassHero.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

# Configure Support bounded context
config :klass_hero, :support,
  repository: KlassHero.Support.Adapters.Driven.Persistence.Repositories.ContactRequestRepository

config :klass_hero,
  ecto_repos: [KlassHero.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :session_id,
    :reason,
    :provider_id,
    :record_id,
    :child_id,
    :program_id,
    :provider_name,
    :attendance_record_id,
    :child_name,
    :limit,
    :has_cursor,
    :returned_count,
    :has_more,
    :errors,
    :error_id,
    :identity_id,
    :business_name,
    :first_name,
    :last_name,
    :parent_id,
    :count,
    :current_user_id,
    :live_view,
    :search_query,
    :result_count,
    :duration_ms,
    :target_ms,
    :page_has_more,
    :event_id,
    :event_type,
    :aggregate_id,
    :topic,
    :error,
    :title,
    :lock_version,
    :cursor,
    :archived_count,
    :cap,
    :category,
    :consent_id,
    :consent_type,
    :contact_id,
    :content,
    :conversation_id,
    :conversations_deleted,
    :current_count,
    :cutoff_date,
    :days_after_program_end,
    :email,
    :end_date,
    :enrollment_id,
    :message,
    :message_id,
    :messages_deleted,
    :name,
    :opts,
    :participant_id,
    :recipient_count,
    :remaining,
    :retention_period_days,
    :start_date,
    :subject,
    :submitted_at,
    :tier,
    :timestamp,
    :type,
    :used,
    :user_count,
    :user_id,
    :conversation_count,
    :initiator_id,
    :message_count,
    :read_at,
    :retention_days,
    :sender_id,
    :note_id,
    :stacktrace
  ]

config :opentelemetry, :resource,
  service: [
    name: "klass-hero",
    namespace: "klass-hero"
  ]

# OpenTelemetry base configuration
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

# GDPR: Filter sensitive parameters from logs
config :phoenix, :filter_parameters, [
  "password",
  "password_confirmation",
  "email",
  "name"
]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  klass_hero: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
