defmodule KlassHero.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    setup_opentelemetry()

    children = infrastructure_children() ++ domain_children() ++ [KlassHeroWeb.Endpoint]

    opts = [strategy: :one_for_one, name: KlassHero.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    KlassHeroWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp setup_opentelemetry do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:klass_hero, :repo])
  end

  defp infrastructure_children do
    [
      KlassHeroWeb.Telemetry,
      KlassHero.Repo,
      {DNSCluster, query: Application.get_env(:klass_hero, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: KlassHero.PubSub},
      {Oban, Application.fetch_env!(:klass_hero, Oban)}
    ]
  end

  defp domain_children do
    domain_event_buses() ++
      event_subscribers() ++
      integration_event_subscribers() ++
      in_memory_repositories()
  end

  defp domain_event_buses do
    # Pre-provisioned for Identity-internal domain events (e.g. child_updated)
    # that will stay within the context — distinct from integration events via PubSub
    [
      {KlassHero.Shared.DomainEventBus, context: KlassHero.Identity}
    ]
  end

  defp event_subscribers do
    [
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: KlassHero.Identity.Adapters.Driven.Events.IdentityEventHandler,
         topics: ["user:user_registered", "user:user_confirmed", "user:user_anonymized"]},
        id: :identity_event_subscriber
      )
    ]
  end

  defp integration_event_subscribers do
    [
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: KlassHero.Participation.Adapters.Driven.Events.ParticipationEventHandler,
         topics: ["integration:identity:child_data_anonymized"],
         message_tag: :integration_event,
         event_label: "Integration event"},
        id: :participation_integration_event_subscriber
      )
    ]
  end

  defp in_memory_repositories do
    [
      KlassHero.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository
    ]
  end
end
