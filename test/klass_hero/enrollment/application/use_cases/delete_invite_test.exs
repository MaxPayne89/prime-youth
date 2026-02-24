defmodule KlassHero.Enrollment.Application.UseCases.DeleteInviteTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.Enrollment.Application.UseCases.DeleteInvite

  describe "execute/1" do
    test "deletes an invite" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      {:ok, _} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "jane@test.com"
          }
        ])

      [invite] = BulkEnrollmentInviteRepository.list_by_program(program.id)

      assert :ok = DeleteInvite.execute(invite.id)
      assert BulkEnrollmentInviteRepository.list_by_program(program.id) == []
    end

    test "returns error for non-existent invite" do
      assert {:error, :not_found} = DeleteInvite.execute(Ecto.UUID.generate())
    end
  end
end
