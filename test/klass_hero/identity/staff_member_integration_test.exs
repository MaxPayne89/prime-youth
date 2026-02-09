defmodule KlassHero.Identity.StaffMemberIntegrationTest do
  use KlassHero.DataCase

  alias KlassHero.Identity
  alias KlassHero.IdentityFixtures

  describe "create_staff_member/1" do
    test "creates with valid attrs" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:ok, staff} =
               Identity.create_staff_member(%{
                 provider_id: provider.id,
                 first_name: "Mike",
                 last_name: "Johnson",
                 role: "Head Coach",
                 tags: ["sports"],
                 qualifications: ["First Aid"]
               })

      assert staff.first_name == "Mike"
      assert staff.tags == ["sports"]
    end

    test "rejects invalid tags" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:error, {:validation_error, errors}} =
               Identity.create_staff_member(%{
                 provider_id: provider.id,
                 first_name: "Mike",
                 last_name: "Johnson",
                 tags: ["invalid_category"]
               })

      assert Enum.any?(errors, &String.contains?(&1, "invalid_category"))
    end
  end

  describe "list_staff_members/1" do
    test "returns staff for provider" do
      provider = IdentityFixtures.provider_profile_fixture()

      _staff =
        IdentityFixtures.staff_member_fixture(provider_id: provider.id, first_name: "Alice")

      assert {:ok, [member]} = Identity.list_staff_members(provider.id)
      assert member.first_name == "Alice"
    end

    test "returns empty list for provider with no staff" do
      provider = IdentityFixtures.provider_profile_fixture()
      assert {:ok, []} = Identity.list_staff_members(provider.id)
    end
  end

  describe "update_staff_member/2" do
    test "updates allowed fields" do
      staff = IdentityFixtures.staff_member_fixture(first_name: "Old", role: "Assistant")

      assert {:ok, updated} = Identity.update_staff_member(staff.id, %{role: "Head Coach"})
      assert updated.role == "Head Coach"
      assert updated.first_name == "Old"
    end

    test "rejects update with invalid data (empty first_name)" do
      staff = IdentityFixtures.staff_member_fixture(first_name: "Valid")

      assert {:error, {:validation_error, errors}} =
               Identity.update_staff_member(staff.id, %{first_name: ""})

      assert "First name cannot be empty" in errors
    end

    test "returns not_found for non-existent staff member" do
      assert {:error, :not_found} =
               Identity.update_staff_member(Ecto.UUID.generate(), %{role: "Coach"})
    end

    test "cannot change provider_id through update" do
      staff = IdentityFixtures.staff_member_fixture()
      other_provider = IdentityFixtures.provider_profile_fixture()

      # Trigger: update with a different provider_id
      # Why: edit_changeset excludes provider_id from cast, so it should be ignored
      # Outcome: provider_id remains unchanged after update
      assert {:ok, updated} =
               Identity.update_staff_member(staff.id, %{
                 provider_id: other_provider.id,
                 role: "New Role"
               })

      assert updated.provider_id == staff.provider_id
      assert updated.role == "New Role"
    end
  end

  describe "delete_staff_member/1" do
    test "deletes existing staff member" do
      staff = IdentityFixtures.staff_member_fixture()
      assert :ok = Identity.delete_staff_member(staff.id)
      assert {:error, :not_found} = Identity.get_staff_member(staff.id)
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Identity.delete_staff_member(Ecto.UUID.generate())
    end
  end

  describe "change_staff_member/2" do
    test "returns a changeset for an existing staff member" do
      staff = IdentityFixtures.staff_member_fixture(first_name: "Original")
      changeset = Identity.change_staff_member(staff)

      assert %Ecto.Changeset{} = changeset
    end

    test "returns a changeset with applied changes" do
      staff = IdentityFixtures.staff_member_fixture(first_name: "Original")
      changeset = Identity.change_staff_member(staff, %{first_name: "Updated"})

      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_field(changeset, :first_name) == "Updated"
    end
  end

  describe "new_staff_member_changeset/1" do
    test "returns an empty changeset with defaults" do
      changeset = Identity.new_staff_member_changeset()
      assert %Ecto.Changeset{} = changeset
    end

    test "returns a changeset with given attrs" do
      changeset = Identity.new_staff_member_changeset(%{first_name: "New"})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_field(changeset, :first_name) == "New"
    end
  end
end
