defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramCatalogIntegrationEventsTest do
  @moduledoc """
  Tests for ProgramCatalogIntegrationEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramCatalogIntegrationEvents

  describe "program_created/3" do
    test "creates event with correct type, source_context, and entity_type" do
      program_id = Ecto.UUID.generate()

      event = ProgramCatalogIntegrationEvents.program_created(program_id)

      assert event.event_type == :program_created
      assert event.source_context == :program_catalog
      assert event.entity_type == :program
      assert event.entity_id == program_id
    end

    test "base_payload program_id wins over caller-supplied program_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{program_id: "should-be-overridden", extra: "data"}

      event = ProgramCatalogIntegrationEvents.program_created(real_id, conflicting_payload)

      assert event.payload.program_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil program_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty program_id string/,
                   fn -> ProgramCatalogIntegrationEvents.program_created(nil) end
    end

    test "raises for empty string program_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty program_id string/,
                   fn -> ProgramCatalogIntegrationEvents.program_created("") end
    end
  end
end
