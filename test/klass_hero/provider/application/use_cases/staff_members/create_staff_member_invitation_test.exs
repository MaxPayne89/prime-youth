defmodule KlassHero.Provider.Application.UseCases.StaffMembers.CreateStaffMemberInvitationTest do
  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Provider.Application.UseCases.StaffMembers.CreateStaffMember
  alias KlassHero.ProviderFixtures

  setup do
    provider = ProviderFixtures.provider_profile_fixture()
    # Set up after fixture creation so events emitted during setup are not collected
    setup_test_integration_events()
    %{provider: provider}
  end

  describe "execute/1 — invitation token generation" do
    test "staff member with email gets invitation_status :pending and token hash", %{
      provider: provider
    } do
      {:ok, staff, _raw_token} =
        CreateStaffMember.execute(%{
          provider_id: provider.id,
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.com"
        })

      assert staff.invitation_status == :pending
      assert staff.invitation_token_hash != nil
    end

    test "staff member without email has nil invitation_status and no token", %{
      provider: provider
    } do
      {:ok, staff} =
        CreateStaffMember.execute(%{
          provider_id: provider.id,
          first_name: "Bob",
          last_name: "Smith"
        })

      assert staff.invitation_status == nil
      assert staff.invitation_token_hash == nil
    end

    test "returns raw_token when email is present", %{provider: provider} do
      {:ok, staff, raw_token} =
        CreateStaffMember.execute(%{
          provider_id: provider.id,
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.com"
        })

      assert is_binary(raw_token)
      assert byte_size(raw_token) > 0

      # Verify the token hashes to the stored hash
      assert :crypto.hash(:sha256, Base.url_decode64!(raw_token, padding: false)) ==
               staff.invitation_token_hash
    end

    test "emits :staff_member_invited integration event when email is present", %{
      provider: provider
    } do
      {:ok, staff, _raw_token} =
        CreateStaffMember.execute(%{
          provider_id: provider.id,
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.com"
        })

      event = assert_integration_event_published(:staff_member_invited)
      assert event.entity_id == staff.id
      assert event.source_context == :provider
      assert event.entity_type == :staff_member
      assert event.payload.staff_member_id == staff.id
      assert event.payload.provider_id == provider.id
      assert event.payload.email == "jane@example.com"
      assert event.payload.first_name == "Jane"
      assert event.payload.last_name == "Doe"
      assert event.payload.business_name == provider.business_name
      assert is_binary(event.payload.raw_token)
    end

    test "does not emit integration event when email is absent", %{provider: provider} do
      {:ok, _staff} =
        CreateStaffMember.execute(%{
          provider_id: provider.id,
          first_name: "Bob",
          last_name: "Smith"
        })

      assert_no_integration_events_published()
    end
  end
end
