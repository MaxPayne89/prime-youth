defmodule KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistryTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistry

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
               {KlassHero.Family.Adapters.Driven.Events.FamilyEventHandler, :handle_event},
               {KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler, :handle_event}
             ] = handlers
    end

    test "returns Family and Provider handlers for user_confirmed" do
      handlers =
        CriticalEventHandlerRegistry.handlers_for("integration:accounts:user_confirmed")

      assert [
               {KlassHero.Family.Adapters.Driven.Events.FamilyEventHandler, :handle_event},
               {KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler, :handle_event}
             ] = handlers
    end

    test "returns Family, Provider, and Messaging handlers for user_anonymized" do
      handlers =
        CriticalEventHandlerRegistry.handlers_for("integration:accounts:user_anonymized")

      assert [
               {KlassHero.Family.Adapters.Driven.Events.FamilyEventHandler, :handle_event},
               {KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler, :handle_event},
               {KlassHero.Messaging.Adapters.Driven.Events.MessagingEventHandler, :handle_event}
             ] = handlers
    end
  end
end
