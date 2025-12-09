defmodule PrimeYouth.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PrimeYouthWeb.Telemetry,
      PrimeYouth.Repo,
      {DNSCluster, query: Application.get_env(:prime_youth, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PrimeYouth.PubSub},
      # Start Highlights in-memory repository
      PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository,
      # Start Family in-memory repository
      PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository,
      # Start Activities in-memory repository
      PrimeYouth.Activities.Adapters.Driven.Persistence.Repositories.InMemoryActivityRepository,
      # Start a worker by calling: PrimeYouth.Worker.start_link(arg)
      # {PrimeYouth.Worker, arg},
      # Start to serve requests, typically the last entry
      PrimeYouthWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PrimeYouth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PrimeYouthWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
