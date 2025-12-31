defmodule PrimeYouth.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    setup_opentelemetry()

    children = infrastructure_children() ++ domain_children() ++ [PrimeYouthWeb.Endpoint]

    opts = [strategy: :one_for_one, name: PrimeYouth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PrimeYouthWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp setup_opentelemetry do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:prime_youth, :repo])
  end

  defp infrastructure_children do
    [
      PrimeYouthWeb.Telemetry,
      PrimeYouth.Repo,
      {DNSCluster, query: Application.get_env(:prime_youth, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PrimeYouth.PubSub}
    ]
  end

  defp domain_children do
    event_subscribers() ++ in_memory_repositories()
  end

  defp event_subscribers do
    [
      Supervisor.child_spec(
        {PrimeYouth.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: PrimeYouth.Identity.Adapters.Driven.Events.IdentityEventHandler,
         topics: ["user:user_registered", "user:user_confirmed"]},
        id: :identity_event_subscriber
      )
    ]
  end

  defp in_memory_repositories do
    [
      PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository,
      # TODO: Remove after Phase 3 (Web Layer) migrates AttendanceHistoryLive to Identity context
      PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository
    ]
  end
end
