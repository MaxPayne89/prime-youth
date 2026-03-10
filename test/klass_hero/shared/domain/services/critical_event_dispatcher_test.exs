defmodule KlassHero.Shared.Domain.Services.CriticalEventDispatcherTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher

  describe "handler_ref/1" do
    test "produces canonical string from {module, function} tuple" do
      ref = CriticalEventDispatcher.handler_ref({MyApp.SomeHandler, :handle_event})
      assert ref == "Elixir.MyApp.SomeHandler:handle_event"
    end

    test "produces different refs for different functions on same module" do
      ref_a = CriticalEventDispatcher.handler_ref({MyApp.Handler, :handle})
      ref_b = CriticalEventDispatcher.handler_ref({MyApp.Handler, :handle_event})
      assert ref_a != ref_b
    end
  end
end
