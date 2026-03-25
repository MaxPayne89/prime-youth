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

    test ":pending -> :accepted succeeds (existing user fast path)" do
      staff = build_staff_member(invitation_status: :pending)

      assert {:ok, %StaffMember{invitation_status: :accepted}} =
               StaffMember.transition_invitation(staff, :accepted)
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

  describe "invitation_expired?/1" do
    test "returns false when invitation_sent_at is nil" do
      staff = build_staff_member(invitation_status: :sent, invitation_sent_at: nil)
      refute StaffMember.invitation_expired?(staff)
    end

    test "returns false when sent less than 7 days ago" do
      sent_at = DateTime.add(DateTime.utc_now(), -6, :day)
      staff = build_staff_member(invitation_status: :sent, invitation_sent_at: sent_at)
      refute StaffMember.invitation_expired?(staff)
    end

    test "returns true when sent exactly 7 days ago" do
      sent_at = DateTime.add(DateTime.utc_now(), -7, :day)
      staff = build_staff_member(invitation_status: :sent, invitation_sent_at: sent_at)
      assert StaffMember.invitation_expired?(staff)
    end

    test "returns true when sent more than 7 days ago" do
      sent_at = DateTime.add(DateTime.utc_now(), -10, :day)
      staff = build_staff_member(invitation_status: :sent, invitation_sent_at: sent_at)
      assert StaffMember.invitation_expired?(staff)
    end
  end

  describe "generate_invitation_token/0" do
    test "returns a {raw_token, hash} tuple" do
      {raw_token, hash} = StaffMember.generate_invitation_token()

      assert is_binary(raw_token)
      assert is_binary(hash)
    end

    test "raw_token is valid base64url" do
      {raw_token, _hash} = StaffMember.generate_invitation_token()

      assert {:ok, _decoded} = Base.url_decode64(raw_token, padding: false)
    end

    test "hash equals sha256 of decoded raw_token" do
      {raw_token, hash} = StaffMember.generate_invitation_token()

      decoded = Base.url_decode64!(raw_token, padding: false)
      assert hash == :crypto.hash(:sha256, decoded)
    end

    test "two calls produce different tokens" do
      {token_a, hash_a} = StaffMember.generate_invitation_token()
      {token_b, hash_b} = StaffMember.generate_invitation_token()

      assert token_a != token_b
      assert hash_a != hash_b
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
