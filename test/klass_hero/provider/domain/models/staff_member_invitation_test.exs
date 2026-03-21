defmodule KlassHero.Provider.Domain.Models.StaffMemberInvitationTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Models.StaffMember

  describe "transition_invitation/2" do
    test "nil -> :pending succeeds" do
      staff = build_staff_member(invitation_status: nil)

      assert {:ok, %StaffMember{invitation_status: :pending}} =
               StaffMember.transition_invitation(staff, :pending)
    end

    test ":pending -> :sent succeeds" do
      staff = build_staff_member(invitation_status: :pending)

      assert {:ok, %StaffMember{invitation_status: :sent}} =
               StaffMember.transition_invitation(staff, :sent)
    end

    test ":pending -> :failed succeeds" do
      staff = build_staff_member(invitation_status: :pending)

      assert {:ok, %StaffMember{invitation_status: :failed}} =
               StaffMember.transition_invitation(staff, :failed)
    end

    test ":sent -> :accepted succeeds" do
      staff = build_staff_member(invitation_status: :sent)

      assert {:ok, %StaffMember{invitation_status: :accepted}} =
               StaffMember.transition_invitation(staff, :accepted)
    end

    test ":sent -> :expired succeeds" do
      staff = build_staff_member(invitation_status: :sent)

      assert {:ok, %StaffMember{invitation_status: :expired}} =
               StaffMember.transition_invitation(staff, :expired)
    end

    test ":failed -> :pending succeeds (resend)" do
      staff = build_staff_member(invitation_status: :failed)

      assert {:ok, %StaffMember{invitation_status: :pending}} =
               StaffMember.transition_invitation(staff, :pending)
    end

    test ":expired -> :pending succeeds (resend)" do
      staff = build_staff_member(invitation_status: :expired)

      assert {:ok, %StaffMember{invitation_status: :pending}} =
               StaffMember.transition_invitation(staff, :pending)
    end

    test ":accepted -> :pending fails (invalid)" do
      staff = build_staff_member(invitation_status: :accepted)

      assert {:error, :invalid_invitation_transition} =
               StaffMember.transition_invitation(staff, :pending)
    end

    test ":sent -> :pending fails (invalid)" do
      staff = build_staff_member(invitation_status: :sent)

      assert {:error, :invalid_invitation_transition} =
               StaffMember.transition_invitation(staff, :pending)
    end

    test "nil -> :sent fails (must go through :pending)" do
      staff = build_staff_member(invitation_status: nil)

      assert {:error, :invalid_invitation_transition} =
               StaffMember.transition_invitation(staff, :sent)
    end
  end

  defp build_staff_member(overrides) do
    defaults = %{
      id: Ecto.UUID.generate(),
      provider_id: Ecto.UUID.generate(),
      first_name: "Jane",
      last_name: "Doe"
    }

    struct!(StaffMember, Map.merge(defaults, Map.new(overrides)))
  end
end
