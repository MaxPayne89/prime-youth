defmodule KlassHero.Messaging.Adapters.Driving.Events.StaffAssignmentHandlerTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository

  alias KlassHero.Messaging.Adapters.Driving.Events.StaffAssignmentHandler
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "handle_event/1 - staff_assigned_to_program" do
    test "upserts projection when staff_user_id is present" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff_user_id = Ecto.UUID.generate()

      event = build_assignment_event(provider.id, program.id, staff_user_id)
      assert :ok = StaffAssignmentHandler.handle_event(event)

      assert [^staff_user_id] =
               ProgramStaffParticipantRepository.get_active_staff_user_ids(program.id)
    end

    test "skips when staff_user_id is nil" do
      event = build_assignment_event(Ecto.UUID.generate(), Ecto.UUID.generate(), nil)
      assert :ok = StaffAssignmentHandler.handle_event(event)
    end

    test "adds staff to existing active conversations for the program" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      parent_user = KlassHero.AccountsFixtures.user_fixture()
      staff_user = KlassHero.AccountsFixtures.user_fixture()
      staff_user_id = staff_user.id

      # Create existing conversation for this program
      conversation =
        insert(:conversation_schema,
          provider_id: provider.id,
          type: "direct",
          program_id: program.id
        )

      insert(:participant_schema, conversation_id: conversation.id, user_id: parent_user.id)

      event = build_assignment_event(provider.id, program.id, staff_user_id)
      assert :ok = StaffAssignmentHandler.handle_event(event)

      # Staff should now be a participant
      assert ParticipantRepository.is_participant?(conversation.id, staff_user_id)
    end
  end

  describe "handle_event/1 - staff_unassigned_from_program" do
    test "deactivates projection entry" do
      provider_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()
      staff_user_id = Ecto.UUID.generate()

      ProgramStaffParticipantRepository.upsert_active(%{
        provider_id: provider_id,
        program_id: program_id,
        staff_user_id: staff_user_id
      })

      event = build_unassignment_event(provider_id, program_id, staff_user_id)
      assert :ok = StaffAssignmentHandler.handle_event(event)

      assert [] = ProgramStaffParticipantRepository.get_active_staff_user_ids(program_id)
    end
  end

  defp build_assignment_event(provider_id, program_id, staff_user_id) do
    %IntegrationEvent{
      event_id: Ecto.UUID.generate(),
      event_type: :staff_assigned_to_program,
      source_context: :provider,
      entity_type: :staff_member,
      entity_id: Ecto.UUID.generate(),
      occurred_at: DateTime.utc_now(),
      payload: %{
        provider_id: provider_id,
        program_id: program_id,
        staff_member_id: Ecto.UUID.generate(),
        staff_user_id: staff_user_id,
        assigned_at: DateTime.utc_now()
      }
    }
  end

  defp build_unassignment_event(provider_id, program_id, staff_user_id) do
    %IntegrationEvent{
      event_id: Ecto.UUID.generate(),
      event_type: :staff_unassigned_from_program,
      source_context: :provider,
      entity_type: :staff_member,
      entity_id: Ecto.UUID.generate(),
      occurred_at: DateTime.utc_now(),
      payload: %{
        provider_id: provider_id,
        program_id: program_id,
        staff_member_id: Ecto.UUID.generate(),
        staff_user_id: staff_user_id,
        unassigned_at: DateTime.utc_now()
      }
    }
  end
end
