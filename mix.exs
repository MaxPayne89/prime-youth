defmodule KlassHero.MixProject do
  use Mix.Project

  def project do
    [
      app: :klass_hero,
      version: "0.1.0",
      elixir: "~> 1.20.0-rc.1",
      erlang: "~> 28.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      # Test coverage configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {KlassHero.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:error_tracker, "~> 0.7"},
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:bcrypt_elixir, "~> 3.0"},
      {:live_debugger, "~> 0.4", only: [:dev]},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_test, "~> 0.9", only: :test, runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.20"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:tidewave, "~> 0.5", only: :dev},
      {:quokka, "~> 2.11", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      # Testing infrastructure
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      {:stream_data, "~> 1.1", only: :test},
      {:faker, github: "naserca/faker", branch: "escape-chars-for-v1.19", only: :test},
      {:mimic, "~> 2.0", only: :test},
      # OpenTelemetry
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_bandit, "~> 0.2"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_ecto, "~> 1.1"},
      {:oban, "~> 2.18"},
      # Object storage (S3-compatible)
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: test_alias(),
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind klass_hero", "esbuild klass_hero"],
      "assets.deploy": [
        "tailwind klass_hero --minify",
        "esbuild klass_hero --minify",
        "phx.digest"
      ],
      "test.clean": ["test.teardown --remove-volumes", "test.setup --force-recreate"],
      "test.watch": ["test.setup", "test.watch.continuous"],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  # Test alias conditional on environment
  # In CI, Docker is already managed by GitHub Actions, so we skip test.setup
  # In local development, we use test.setup to manage Docker containers
  defp test_alias do
    if System.get_env("CI") do
      ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    else
      ["test.setup", "test.db.setup", "ecto.create --quiet", "ecto.migrate --quiet", "test"]
    end
  end
end
