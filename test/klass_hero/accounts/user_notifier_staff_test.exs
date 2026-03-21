defmodule KlassHero.Accounts.UserNotifierStaffTest do
  use ExUnit.Case, async: true

  alias KlassHero.Accounts.UserNotifier

  describe "deliver_staff_invitation/3" do
    test "delivers staff invitation email with registration link" do
      assert {:ok, email} =
               UserNotifier.deliver_staff_invitation(
                 "staff@example.com",
                 %{business_name: "Fun Academy", first_name: "Jane"},
                 "http://localhost:4000/users/staff-invitation/test-token"
               )

      assert email.to == [{"", "staff@example.com"}]
      assert email.subject =~ "Fun Academy"
      assert email.text_body =~ "test-token"
      assert email.text_body =~ "Fun Academy"
      assert email.text_body =~ "Jane"
    end
  end

  describe "deliver_staff_added_notification/2" do
    test "delivers notification email for existing users" do
      assert {:ok, email} =
               UserNotifier.deliver_staff_added_notification(
                 "existing@example.com",
                 %{business_name: "Cool Sports"}
               )

      assert email.to == [{"", "existing@example.com"}]
      assert email.subject =~ "Cool Sports"
      assert email.text_body =~ "Cool Sports"
      assert email.text_body =~ "/staff/dashboard"
    end
  end
end
