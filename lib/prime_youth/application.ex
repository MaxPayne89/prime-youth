defmodule PrimeYouth.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PrimeYouthWeb.Telemetry,
      PrimeYouth.Repo,
      {DNSCluster, query: Application.get_env(:prime_youth, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PrimeYouth.PubSub},
      Supervisor.child_spec(
        {PrimeYouth.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: PrimeYouth.Family.Adapters.Driven.Events.UserEventHandler,
         topics: ["user:user_registered", "user:user_confirmed"]},
        id: :family_event_subscriber
      ),
      Supervisor.child_spec(
        {PrimeYouth.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: PrimeYouth.Parenting.Adapters.Driven.Events.IdentityEventHandler,
         topics: ["user:user_registered"]},
        id: :parenting_event_subscriber
      ),
      Supervisor.child_spec(
        {PrimeYouth.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: PrimeYouth.Providing.Adapters.Driven.Events.IdentityEventHandler,
         topics: ["user:user_registered"]},
        id: :providing_event_subscriber
      ),
      PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository,
      PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository,
      PrimeYouth.Activities.Adapters.Driven.Persistence.Repositories.InMemoryActivityRepository,
      # Start a worker by calling: PrimeYouth.Worker.start_link(arg)
      # {PrimeYouth.Worker, arg},
      PrimeYouthWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: PrimeYouth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PrimeYouthWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
