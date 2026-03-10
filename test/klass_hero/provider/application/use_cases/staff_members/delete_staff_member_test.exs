defmodule KlassHero.Provider.Application.UseCases.StaffMembers.DeleteStaffMemberTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Application.UseCases.StaffMembers.DeleteStaffMember
  alias KlassHero.ProviderFixtures

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  setup do
    provider = ProviderFixtures.provider_profile_fixture()
    staff = ProviderFixtures.staff_member_fixture(provider_id: provider.id)
    %{staff: staff}
  end

  describe "execute/1" do
    test "deletes an existing staff member", %{staff: staff} do
      assert :ok = DeleteStaffMember.execute(staff.id)
      assert {:error, :not_found} = @repository.get(staff.id)
    end

    test "returns :not_found for non-existent staff member" do
      fake_id = Ecto.UUID.generate()
      assert {:error, :not_found} = DeleteStaffMember.execute(fake_id)
    end

    test "does not affect other staff members", %{staff: staff} do
      provider_id = staff.provider_id
      other_staff = ProviderFixtures.staff_member_fixture(provider_id: provider_id)

      assert :ok = DeleteStaffMember.execute(staff.id)

      assert {:ok, _} = @repository.get(other_staff.id)
    end
  end
end
