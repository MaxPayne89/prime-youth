defmodule KlassHero.Enrollment.Adapters.Driven.Notifications.InviteEmailNotifierTest do
  @moduledoc """
  Tests for the InviteEmailNotifier adapter.

  Uses Swoosh.Adapters.Test (configured in test env) which returns
  {:ok, %{}} from Mailer.deliver/1, so send_invite/3 returns {:ok, email}.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Notifications.InviteEmailNotifier

  defp build_invite(overrides \\ %{}) do
    Map.merge(
      %{
        guardian_email: "parent@example.com",
        guardian_first_name: "Hans",
        child_first_name: "Emma",
        child_last_name: "Schmidt",
        invite_token: "test-token-abc"
      },
      overrides
    )
  end

  @url "https://app.klasshero.com/invites/test-token-abc"

  describe "send_invite/3" do
    test "delivers email with correct recipient and subject" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.to == [{"Hans", "parent@example.com"}]
      assert email.subject =~ "Emma"
      assert email.subject =~ "Dance Class"
    end

    test "uses mailer_defaults sender" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.from == {"KlassHero", "noreply@mail.klasshero.com"}
    end

    test "includes invite URL in text body" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.text_body =~ @url
      assert email.text_body =~ "Emma"
      assert email.text_body =~ "Dance Class"
    end

    test "includes invite URL and child name in HTML body" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.html_body =~ @url
      assert email.html_body =~ "Emma"
      assert email.html_body =~ "Dance Class"
    end

    test "falls back to email as recipient name when guardian_first_name is nil" do
      invite = build_invite(%{guardian_first_name: nil})
      {:ok, email} = InviteEmailNotifier.send_invite(invite, "Dance Class", @url)

      assert email.to == [{"parent@example.com", "parent@example.com"}]
    end
  end
end
