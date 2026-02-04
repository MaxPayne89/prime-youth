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
         context: KlassHero.Identity,
         handlers: [
           {:child_data_anonymized,
            {KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
             :handle}, priority: 10}
         ]},
        id: :identity_domain_event_bus
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
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.Community,
         handlers: [
           {:comment_added,
            {KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
           {:post_liked,
            {KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
           {:post_unliked,
            {KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}}
         ]},
        id: :community_domain_event_bus
      ),
      Supervisor.child_spec(
        {KlassHero.Shared.DomainEventBus,
         context: KlassHero.Support,
         handlers: [
           {:contact_request_submitted,
            {KlassHero.Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}}
         ]},
        id: :support_domain_event_bus
      )
    ]
  end

  defp event_subscribers, do: []

  defp integration_event_subscribers do
    [
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: KlassHero.Identity.Adapters.Driven.Events.IdentityEventHandler,
         topics: [
           "integration:accounts:user_registered",
           "integration:accounts:user_anonymized"
         ],
         message_tag: :integration_event,
         event_label: "Integration event"},
        id: :identity_integration_event_subscriber
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
