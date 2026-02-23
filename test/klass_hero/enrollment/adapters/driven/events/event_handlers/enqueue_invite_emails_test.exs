defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmailsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmails

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Repo

  defp create_pending_invites(_context) do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id, title: "Dance Class")

    rows = [
      %{
        program_id: program.id,
        provider_id: provider.id,
        child_first_name: "Emma",
        child_last_name: "Schmidt",
        child_date_of_birth: ~D[2016-03-15],
        guardian_email: "parent@example.com",
        guardian_first_name: "Hans"
      },
      %{
        program_id: program.id,
        provider_id: provider.id,
        child_first_name: "Liam",
        child_last_name: "Mueller",
        child_date_of_birth: ~D[2017-01-10],
        guardian_email: "other@example.com",
        guardian_first_name: "Maria"
      }
    ]

    {:ok, 2} = BulkEnrollmentInviteRepository.create_batch(rows)
    %{provider: provider, program: program}
  end

  describe "handle/1" do
    setup :create_pending_invites

    test "assigns tokens to all pending invites", %{provider: provider, program: program} do
      event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 2)
      assert :ok = EnqueueInviteEmails.handle(event)

      invites = Repo.all(BulkEnrollmentInviteSchema)
      assert Enum.all?(invites, fn inv -> inv.invite_token != nil end)
      assert length(Enum.uniq_by(invites, & &1.invite_token)) == 2
    end

    test "does nothing when no pending invites exist", %{provider: provider, program: program} do
      Repo.update_all(BulkEnrollmentInviteSchema, set: [status: "failed", error_details: "test"])

      event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 0)
      assert :ok = EnqueueInviteEmails.handle(event)
    end

    test "skips invites that already have tokens", %{provider: provider, program: program} do
      invite = Repo.all(BulkEnrollmentInviteSchema) |> hd()
      invite |> Ecto.Changeset.change(%{invite_token: "pre-existing"}) |> Repo.update!()

      event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 2)
      assert :ok = EnqueueInviteEmails.handle(event)

      invites = Repo.all(BulkEnrollmentInviteSchema)
      assert Enum.find(invites, &(&1.invite_token == "pre-existing")) != nil
    end
  end
end
