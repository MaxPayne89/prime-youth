defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Repo

  defp setup_program(_context) do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    %{provider: provider, program: program}
  end

  defp valid_invite_attrs(program, provider, overrides \\ %{}) do
    Map.merge(
      %{
        program_id: program.id,
        provider_id: provider.id,
        child_first_name: "Emma",
        child_last_name: "Schmidt",
        child_date_of_birth: ~D[2016-03-15],
        guardian_email: "parent@example.com"
      },
      overrides
    )
  end

  describe "create_batch/1" do
    setup :setup_program

    test "inserts valid rows and returns count", %{program: program, provider: provider} do
      rows = [
        valid_invite_attrs(program, provider),
        valid_invite_attrs(program, provider, %{
          child_first_name: "Liam",
          child_last_name: "Mueller",
          child_date_of_birth: ~D[2017-07-20],
          guardian_email: "other@example.com"
        })
      ]

      assert {:ok, 2} = BulkEnrollmentInviteRepository.create_batch(rows)
      assert Repo.aggregate(BulkEnrollmentInviteSchema, :count) == 2
    end

    test "rolls back entire batch when one row is invalid", %{
      program: program,
      provider: provider
    } do
      rows = [
        valid_invite_attrs(program, provider),
        # Missing required child_last_name
        valid_invite_attrs(program, provider, %{child_last_name: nil, guardian_email: "b@x.com"})
      ]

      assert {:error, %Ecto.Changeset{}} = BulkEnrollmentInviteRepository.create_batch(rows)

      # Trigger: transaction rolled back
      # Why: atomicity guarantee — no partial batch inserts
      # Outcome: zero rows persisted
      assert Repo.aggregate(BulkEnrollmentInviteSchema, :count) == 0
    end

    test "returns {:ok, 0} for empty list" do
      assert {:ok, 0} = BulkEnrollmentInviteRepository.create_batch([])
    end

    test "persists all optional fields", %{program: program, provider: provider} do
      attrs =
        valid_invite_attrs(program, provider, %{
          guardian_first_name: "Hans",
          guardian_last_name: "Schmidt",
          guardian2_email: "other-parent@example.com",
          guardian2_first_name: "Maria",
          guardian2_last_name: "Schmidt",
          school_grade: 3,
          school_name: "Grundschule Mitte",
          medical_conditions: "Asthma",
          nut_allergy: true,
          consent_photo_marketing: true,
          consent_photo_social_media: false
        })

      assert {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([attrs])

      invite = Repo.one!(BulkEnrollmentInviteSchema)
      assert invite.guardian_first_name == "Hans"
      assert invite.school_grade == 3
      assert invite.nut_allergy == true
      assert invite.consent_photo_marketing == true
      assert invite.status == "pending"
    end
  end

  describe "list_existing_keys_for_programs/1" do
    setup :setup_program

    test "returns MapSet of existing keys", %{program: program, provider: provider} do
      rows = [
        valid_invite_attrs(program, provider, %{
          child_first_name: "Emma",
          child_last_name: "Schmidt",
          guardian_email: "Parent@Example.com"
        })
      ]

      {:ok, 1} = BulkEnrollmentInviteRepository.create_batch(rows)

      result = BulkEnrollmentInviteRepository.list_existing_keys_for_programs([program.id])

      assert MapSet.size(result) == 1

      # Trigger: email and names are lowercased in the MapSet
      # Why: case-insensitive duplicate detection
      # Outcome: callers can compare normalized keys
      assert MapSet.member?(result, {program.id, "parent@example.com", "emma", "schmidt"})
    end

    test "returns empty MapSet when no matching programs exist" do
      non_existent_id = Ecto.UUID.generate()
      result = BulkEnrollmentInviteRepository.list_existing_keys_for_programs([non_existent_id])
      assert MapSet.size(result) == 0
    end

    test "returns empty MapSet for empty list" do
      result = BulkEnrollmentInviteRepository.list_existing_keys_for_programs([])
      assert result == MapSet.new()
    end

    test "includes keys from multiple programs", %{provider: provider} do
      program_a = insert(:program_schema, provider_id: provider.id)
      program_b = insert(:program_schema, provider_id: provider.id)

      rows = [
        valid_invite_attrs(program_a, provider, %{
          child_first_name: "Anna",
          guardian_email: "a@test.com"
        }),
        valid_invite_attrs(program_b, provider, %{
          child_first_name: "Ben",
          guardian_email: "b@test.com"
        })
      ]

      {:ok, 2} = BulkEnrollmentInviteRepository.create_batch(rows)

      result =
        BulkEnrollmentInviteRepository.list_existing_keys_for_programs([
          program_a.id,
          program_b.id
        ])

      assert MapSet.size(result) == 2
      assert MapSet.member?(result, {program_a.id, "a@test.com", "anna", "schmidt"})
      assert MapSet.member?(result, {program_b.id, "b@test.com", "ben", "schmidt"})
    end
  end
end
