defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderProgramsTest do
  use KlassHero.DataCase, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProgramProjectionSchema
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderPrograms
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  defp build_event(event_type, payload) do
    %IntegrationEvent{
      event_id: Ecto.UUID.generate(),
      event_type: event_type,
      source_context: :program_catalog,
      entity_type: :program,
      entity_id: payload.program_id,
      occurred_at: DateTime.utc_now(),
      payload: payload,
      metadata: %{},
      version: 1
    }
  end

  defp start_projection! do
    {:ok, pid} =
      ProviderPrograms.start_link(
        name: :"test_proj_#{System.unique_integer([:positive])}",
        skip_bootstrap: true
      )

    Sandbox.allow(Repo, self(), pid)
    pid
  end

  defp send_event!(pid, event_type, payload) do
    send(pid, {:integration_event, build_event(event_type, payload)})
    # Synchronize -- :sys.get_state blocks until the GenServer drains its mailbox
    :sys.get_state(pid)
  end

  describe "handle_info/2 :program_created event" do
    test "upserts a new row with provider_id, name, and status" do
      pid = start_projection!()
      program_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      send_event!(pid, :program_created, %{
        program_id: program_id,
        provider_id: provider_id,
        title: "Drawing Club"
      })

      row = Repo.get(ProviderProgramProjectionSchema, program_id)
      assert row.provider_id == provider_id
      assert row.name == "Drawing Club"
      assert row.status == "active"
    end
  end

  describe "handle_info/2 :program_updated event" do
    test "updates existing row's name without creating duplicates" do
      pid = start_projection!()
      program_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      send_event!(pid, :program_created, %{
        program_id: program_id,
        provider_id: provider_id,
        title: "Old name"
      })

      send_event!(pid, :program_updated, %{
        program_id: program_id,
        provider_id: provider_id,
        title: "New name"
      })

      assert Repo.aggregate(ProviderProgramProjectionSchema, :count) == 1

      row = Repo.get(ProviderProgramProjectionSchema, program_id)
      assert row.name == "New name"
    end
  end
end
