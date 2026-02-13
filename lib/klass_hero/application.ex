defmodule KlassHero.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [
      KlassHero,
      KlassHeroWeb,
      KlassHero.Accounts,
      KlassHero.Family,
      KlassHero.Provider,
      KlassHero.ProgramCatalog,
      KlassHero.Enrollment,
      KlassHero.Messaging,
      KlassHero.Participation,
      KlassHero.Shared
    ]

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
      integration_event_subscribers() ++
      in_memory_projections() ++
      in_memory_repositories()
  end

  defp domain_event_buses do
    [
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.Accounts,
         handlers: [
           {:user_registered,
            {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
             :handle}, priority: 10},
           {:user_anonymized,
            {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
             :handle}, priority: 10}
         ]},
        id: :accounts_domain_event_bus
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.Family,
         handlers: [
           {:child_data_anonymized,
            {KlassHero.Family.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
             :handle}, priority: 10}
         ]},
        id: :family_domain_event_bus
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.Provider,
         handlers: []},
        id: :provider_domain_event_bus
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.ProgramCatalog,
         handlers: [
           {:program_created,
            {KlassHero.ProgramCatalog.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
             :handle}, priority: 10}
         ]},
        id: :program_catalog_domain_event_bus
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.Messaging,
         handlers: [
           {:user_data_anonymized,
            {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
             :handle}, priority: 10},
           {:message_sent,
            {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
           {:messages_read,
            {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
           {:broadcast_sent,
            {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
           {:conversation_created,
            {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
           {:conversations_archived,
            {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
           {:retention_enforced,
            {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}}
         ]},
        id: :messaging_domain_event_bus
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.Participation,
         handlers: [
           {:session_created,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:session_started,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:session_completed,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:child_checked_in,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:child_checked_out,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:child_marked_absent,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:behavioral_note_submitted,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:behavioral_note_approved,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
           {:behavioral_note_rejected,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}}
         ]},
        id: :participation_domain_event_bus
      ),
    ]
  end

  defp integration_event_subscribers do
    [
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: KlassHero.Family.Adapters.Driven.Events.FamilyEventHandler,
         topics: [
           "integration:accounts:user_registered",
           "integration:accounts:user_anonymized"
         ],
         message_tag: :integration_event,
         event_label: "Integration event"},
        id: :family_integration_event_subscriber
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler,
         topics: [
           "integration:accounts:user_registered",
           "integration:accounts:user_anonymized"
         ],
         message_tag: :integration_event,
         event_label: "Integration event"},
        id: :provider_integration_event_subscriber
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: KlassHero.Messaging.Adapters.Driven.Events.MessagingEventHandler,
         topics: ["integration:accounts:user_anonymized"],
         message_tag: :integration_event,
         event_label: "Integration event"},
        id: :messaging_integration_event_subscriber
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: KlassHero.Participation.Adapters.Driven.Events.ParticipationEventHandler,
         topics: ["integration:family:child_data_anonymized"],
         message_tag: :integration_event,
         event_label: "Integration event"},
        id: :participation_integration_event_subscriber
      )
    ]
  end

  defp in_memory_projections do
    [
      KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
    ]
  end

  defp in_memory_repositories do
    []
  end
end