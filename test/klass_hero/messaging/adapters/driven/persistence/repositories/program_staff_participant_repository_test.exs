defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository

  @provider_id Ecto.UUID.generate()
  @program_id Ecto.UUID.generate()

  describe "upsert_active/1" do
    test "inserts new active staff participant" do
      staff_user_id = Ecto.UUID.generate()

      assert :ok =
               ProgramStaffParticipantRepository.upsert_active(%{
                 provider_id: @provider_id,
                 program_id: @program_id,
                 staff_user_id: staff_user_id
               })

      assert [^staff_user_id] =
               ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
    end

    test "reactivates previously deactivated participant" do
      staff_user_id = Ecto.UUID.generate()
      attrs = %{provider_id: @provider_id, program_id: @program_id, staff_user_id: staff_user_id}

      :ok = ProgramStaffParticipantRepository.upsert_active(attrs)
      :ok = ProgramStaffParticipantRepository.deactivate(@program_id, staff_user_id)
      assert [] = ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)

      :ok = ProgramStaffParticipantRepository.upsert_active(attrs)

      assert [^staff_user_id] =
               ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
    end
  end

  describe "deactivate/2" do
    test "marks staff participant as inactive" do
      staff_user_id = Ecto.UUID.generate()

      :ok =
        ProgramStaffParticipantRepository.upsert_active(%{
          provider_id: @provider_id,
          program_id: @program_id,
          staff_user_id: staff_user_id
        })

      :ok = ProgramStaffParticipantRepository.deactivate(@program_id, staff_user_id)
      assert [] = ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
    end

    test "is a no-op for non-existent participant" do
      assert :ok =
               ProgramStaffParticipantRepository.deactivate(
                 Ecto.UUID.generate(),
                 Ecto.UUID.generate()
               )
    end
  end

  describe "get_active_staff_user_ids/1" do
    test "returns only active staff for program" do
      staff1 = Ecto.UUID.generate()
      staff2 = Ecto.UUID.generate()

      :ok =
        ProgramStaffParticipantRepository.upsert_active(%{
          provider_id: @provider_id,
          program_id: @program_id,
          staff_user_id: staff1
        })

      :ok =
        ProgramStaffParticipantRepository.upsert_active(%{
          provider_id: @provider_id,
          program_id: @program_id,
          staff_user_id: staff2
        })

      :ok = ProgramStaffParticipantRepository.deactivate(@program_id, staff2)

      active = ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
      assert active == [staff1]
    end
  end
end
