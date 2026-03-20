defmodule KlassHeroWeb.ResendWebhookControllerTest do
  use KlassHeroWeb.ConnCase, async: true

  @valid_payload %{
    "type" => "email.received",
    "data" => %{
      "email_id" => "resend_test_#{System.unique_integer([:positive])}",
      "from" => "sender@example.com",
      "to" => ["hello@klasshero.com"],
      "subject" => "Test Email",
      "html" => "<p>Hello</p>",
      "text" => "Hello",
      "headers" => [%{"name" => "Message-ID", "value" => "<abc@example.com>"}],
      "created_at" => "2026-03-20T10:00:00Z"
    }
  }

  describe "POST /webhooks/resend" do
    test "returns 200 for valid email.received event", %{conn: conn} do
      conn = post(conn, ~p"/webhooks/resend", @valid_payload)
      assert json_response(conn, 200)
    end

    test "returns 200 for duplicate (idempotent)", %{conn: conn} do
      payload =
        put_in(@valid_payload, ["data", "email_id"], "dup_#{System.unique_integer([:positive])}")

      post(conn, ~p"/webhooks/resend", payload)
      conn2 = post(conn, ~p"/webhooks/resend", payload)
      assert json_response(conn2, 200)
    end

    test "returns 200 for unhandled event types", %{conn: conn} do
      payload = %{"type" => "email.delivered", "data" => %{}}
      conn = post(conn, ~p"/webhooks/resend", payload)
      assert json_response(conn, 200)
    end
  end
end
