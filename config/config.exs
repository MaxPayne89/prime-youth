# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :error_tracker, repo: PrimeYouth.Repo, otp_app: :prime_youth, enabled: true

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  prime_youth: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

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

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# Configures the endpoint
config :prime_youth, PrimeYouth.Mailer, adapter: Swoosh.Adapters.Local

config :prime_youth, PrimeYouthWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PrimeYouthWeb.ErrorHTML, json: PrimeYouthWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PrimeYouth.PubSub,
  live_view: [signing_salt: "JU2osypv"]

# Configure Gettext for internationalization
config :prime_youth, PrimeYouthWeb.Gettext,
  default_locale: "en",
  locales: ~w(en de)

# Configure Attendance bounded context
config :prime_youth, :attendance,
  session_repository:
    PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.SessionRepository,
  attendance_repository:
    PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.AttendanceRepository,
  child_name_resolver: PrimeYouth.Attendance.Adapters.Driven.FamilyContext.ChildNameResolver

# Configure Event Publisher
config :prime_youth, :event_publisher,
  module: PrimeYouth.Shared.Adapters.Driven.Events.PubSubEventPublisher,
  pubsub: PrimeYouth.PubSub

# Configure Family bounded context
config :prime_youth, :family,
  repository: PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository,
  child_repository: PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepository

# Configure Highlights bounded context
config :prime_youth, :highlights,
  repository:
    PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository

# Configure Identity bounded context
config :prime_youth, :identity,
  for_storing_parent_profiles:
    PrimeYouth.Identity.Adapters.Driven.Persistence.Repositories.ParentProfileRepository,
  for_storing_provider_profiles:
    PrimeYouth.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository,
  for_storing_children:
    PrimeYouth.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository

# Configure Parenting bounded context
config :prime_youth, :parenting,
  repository: PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepository

# Configure Program Catalog bounded context
config :prime_youth, :program_catalog,
  repository: PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository

# Configure Providing bounded context
config :prime_youth, :providing,
  repository: PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepository

config :prime_youth, :scopes,
  user: [
    default: true,
    module: PrimeYouth.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: PrimeYouth.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

# Configure Support bounded context
config :prime_youth, :support,
  repository: PrimeYouth.Support.Adapters.Driven.Persistence.Repositories.ContactRequestRepository

config :prime_youth,
  ecto_repos: [PrimeYouth.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  prime_youth: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
