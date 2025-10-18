# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

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

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :prime_youth, PrimeYouth.Mailer, adapter: Swoosh.Adapters.Local

# Configures the endpoint
config :prime_youth, PrimeYouthWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PrimeYouthWeb.ErrorHTML, json: PrimeYouthWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PrimeYouth.PubSub,
  live_view: [signing_salt: "JU2osypv"]

config :prime_youth, :scopes,
  user: [
    default: true,
    module: PrimeYouth.Auth.Infrastructure.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: PrimeYouth.AuthFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :prime_youth,
  ecto_repos: [PrimeYouth.Repo],
  generators: [timestamp_type: :utc_datetime],
  # Auth ports configuration - dependency injection (3 driven ports)
  base_url: "http://localhost:4000"

config :prime_youth,
  repository: PrimeYouth.Auth.Adapters.Driven.Persistence.Repositories.UserRepository,
  password_hasher: PrimeYouth.Auth.Adapters.Driven.PasswordHashing.BcryptPasswordHasher,
  notifier: PrimeYouth.Auth.Adapters.Driven.Notifications.EmailNotifier

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  prime_youth: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),

    # Import environment specific config. This must remain at the bottom
    # of this file so it overrides the configuration defined above.
    cd: Path.expand("..", __DIR__)
  ]

import_config "#{config_env()}.exs"
