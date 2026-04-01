defmodule KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistryTest do
  use ExUnit.Case, async: true

  alias KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents
  alias KlassHero.Family.Adapters.Driving.Events.FamilyEventHandler
  alias KlassHero.Messaging.Adapters.Driving.Events.MessagingEventHandler
  alias KlassHero.Provider.Adapters.Driving.Events.ProviderEventHandler
  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistry
  alias KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher

  describe "handlers_for/1" do
    test "returns handler tuples for a configured topic" do
      # Uses whatever is in test config
      handlers =
        CriticalEventHandlerRegistry.handlers_for("integration:enrollment:invite_claimed")

      assert is_list(handlers)
      refute Enum.empty?(handlers)
      assert {module, function} = hd(handlers)
      assert is_atom(module)
      assert is_atom(function)
    end

    test "returns empty list for unconfigured topic" do
      assert [] == CriticalEventHandlerRegistry.handlers_for("integration:unknown:topic")
    end

    test "returns Family and Provider handlers for user_registered" do
      handlers =
        CriticalEventHandlerRegistry.handlers_for("integration:accounts:user_registered")

      assert [
               {FamilyEventHandler, :handle_event},
               {ProviderEventHandler, :handle_event}
             ] = handlers
    end

    test "returns Family and Provider handlers for user_confirmed" do
      handlers =
        CriticalEventHandlerRegistry.handlers_for("integration:accounts:user_confirmed")

      assert [
               {FamilyEventHandler, :handle_event},
               {ProviderEventHandler, :handle_event}
             ] = handlers
    end

    test "returns Family, Provider, and Messaging handlers for user_anonymized" do
      handlers =
        CriticalEventHandlerRegistry.handlers_for("integration:accounts:user_anonymized")

      assert [
               {FamilyEventHandler, :handle_event},
               {ProviderEventHandler, :handle_event},
               {MessagingEventHandler, :handle_event}
             ] = handlers
    end
  end

  describe "end-to-end wiring: AccountsIntegrationEvents factory → topic → registry" do
    test "user_registered factory produces a topic that resolves to 2 handlers" do
      event = AccountsIntegrationEvents.user_registered("user-1")
      topic = PubSubIntegrationEventPublisher.derive_topic(event)
      handlers = CriticalEventHandlerRegistry.handlers_for(topic)

      assert length(handlers) == 2

      assert {FamilyEventHandler, :handle_event} in handlers

      assert {ProviderEventHandler, :handle_event} in handlers
    end

    test "user_confirmed factory produces a topic that resolves to 2 handlers" do
      event = AccountsIntegrationEvents.user_confirmed("user-1")
      topic = PubSubIntegrationEventPublisher.derive_topic(event)
      handlers = CriticalEventHandlerRegistry.handlers_for(topic)

      assert length(handlers) == 2

      assert {FamilyEventHandler, :handle_event} in handlers

      assert {ProviderEventHandler, :handle_event} in handlers
    end

    test "user_anonymized factory produces a topic that resolves to 3 handlers" do
      event = AccountsIntegrationEvents.user_anonymized("user-1")
      topic = PubSubIntegrationEventPublisher.derive_topic(event)
      handlers = CriticalEventHandlerRegistry.handlers_for(topic)

      assert length(handlers) == 3

      assert {FamilyEventHandler, :handle_event} in handlers

      assert {ProviderEventHandler, :handle_event} in handlers

      assert {MessagingEventHandler, :handle_event} in handlers
    end
  end
end
