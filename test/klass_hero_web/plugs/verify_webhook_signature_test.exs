defmodule KlassHeroWeb.Plugs.VerifyWebhookSignatureTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias KlassHeroWeb.Plugs.VerifyWebhookSignature

  @raw_body ~s({"type":"email.received","data":{"email_id":"test_123"}})

  setup do
    secret_bytes = :crypto.strong_rand_bytes(32)
    secret = "whsec_#{Base.encode64(secret_bytes)}"

    original_verify = Application.get_env(:klass_hero, :verify_webhook_signature)
    original_secret = Application.get_env(:klass_hero, :resend_webhook_secret)

    Application.put_env(:klass_hero, :verify_webhook_signature, true)
    Application.put_env(:klass_hero, :resend_webhook_secret, secret)

    on_exit(fn ->
      restore_env(:verify_webhook_signature, original_verify)
      restore_env(:resend_webhook_secret, original_secret)
    end)

    %{secret: secret, secret_bytes: secret_bytes}
  end

  defp restore_env(key, nil), do: Application.delete_env(:klass_hero, key)
  defp restore_env(key, value), do: Application.put_env(:klass_hero, key, value)

  defp base_conn do
    conn(:post, "/webhooks/resend")
    |> assign(:raw_body, @raw_body)
  end

  defp add_svix_headers(conn, svix_id, svix_timestamp, signature_header) do
    conn
    |> put_req_header("svix-id", svix_id)
    |> put_req_header("svix-timestamp", svix_timestamp)
    |> put_req_header("svix-signature", signature_header)
  end

  defp compute_signature(secret_bytes, svix_id, svix_timestamp, body) do
    signed_content = "#{svix_id}.#{svix_timestamp}.#{body}"
    :crypto.mac(:hmac, :sha256, secret_bytes, signed_content) |> Base.encode64()
  end

  defp current_timestamp, do: Integer.to_string(System.system_time(:second))

  describe "call/2 - verification bypass" do
    test "passes through without checking headers when verification is disabled" do
      Application.put_env(:klass_hero, :verify_webhook_signature, false)

      conn =
        conn(:post, "/webhooks/resend")
        |> VerifyWebhookSignature.call([])

      refute conn.halted
    end
  end

  describe "call/2 - valid signature" do
    test "passes through with a correctly computed Svix signature", %{secret_bytes: secret_bytes} do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()
      sig = compute_signature(secret_bytes, svix_id, svix_timestamp, @raw_body)

      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      refute conn.halted
    end

    test "accepts any matching signature from space-separated list (key rotation)", %{
      secret_bytes: secret_bytes
    } do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()
      valid_sig = compute_signature(secret_bytes, svix_id, svix_timestamp, @raw_body)

      # First signature is wrong; second is correct — any match should pass
      combined = "v1,#{Base.encode64("wrong_sig_bytes")} v1,#{valid_sig}"

      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, combined)
        |> VerifyWebhookSignature.call([])

      refute conn.halted
    end
  end

  describe "call/2 - invalid signature" do
    test "halts with 401 when signature does not match" do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()

      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, "v1,#{Base.encode64("not_the_right_hmac")}")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts when signature is computed over a different body", %{secret_bytes: secret_bytes} do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()

      # Sign a different body than what's in raw_body
      sig = compute_signature(secret_bytes, svix_id, svix_timestamp, ~s({"tampered":"payload"}))

      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts when all signatures in the list are invalid" do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()

      combined =
        "v1,#{Base.encode64("bad_sig_one")} v1,#{Base.encode64("bad_sig_two")}"

      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, combined)
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - missing required fields" do
    test "halts with 401 when svix-id header is missing", %{secret_bytes: secret_bytes} do
      svix_timestamp = current_timestamp()
      sig = compute_signature(secret_bytes, "msg_1", svix_timestamp, @raw_body)

      conn =
        base_conn()
        |> put_req_header("svix-timestamp", svix_timestamp)
        |> put_req_header("svix-signature", "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts with 401 when svix-timestamp header is missing", %{secret_bytes: secret_bytes} do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      sig = compute_signature(secret_bytes, svix_id, "1234567890", @raw_body)

      conn =
        base_conn()
        |> put_req_header("svix-id", svix_id)
        |> put_req_header("svix-signature", "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts with 401 when svix-signature header is missing" do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()

      conn =
        base_conn()
        |> put_req_header("svix-id", svix_id)
        |> put_req_header("svix-timestamp", svix_timestamp)
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts with 401 when raw_body is not assigned", %{secret_bytes: secret_bytes} do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()
      sig = compute_signature(secret_bytes, svix_id, svix_timestamp, @raw_body)

      # Intentionally no raw_body assign
      conn =
        conn(:post, "/webhooks/resend")
        |> add_svix_headers(svix_id, svix_timestamp, "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - timestamp validation" do
    test "halts with 401 when timestamp is more than 5 minutes old", %{
      secret_bytes: secret_bytes
    } do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      # 6 minutes ago
      old_timestamp = Integer.to_string(System.system_time(:second) - 361)
      sig = compute_signature(secret_bytes, svix_id, old_timestamp, @raw_body)

      conn =
        base_conn()
        |> add_svix_headers(svix_id, old_timestamp, "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "passes when timestamp is within the 5-minute window", %{secret_bytes: secret_bytes} do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      # 4 minutes ago — within the 5-minute window
      recent_timestamp = Integer.to_string(System.system_time(:second) - 239)
      sig = compute_signature(secret_bytes, svix_id, recent_timestamp, @raw_body)

      conn =
        base_conn()
        |> add_svix_headers(svix_id, recent_timestamp, "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      refute conn.halted
    end

    test "halts with 401 when timestamp is not a valid integer" do
      svix_id = "msg_#{System.unique_integer([:positive])}"

      conn =
        base_conn()
        |> add_svix_headers(svix_id, "not-a-number", "v1,whatever")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - secret configuration errors" do
    test "halts with 401 when resend_webhook_secret is not configured" do
      Application.delete_env(:klass_hero, :resend_webhook_secret)

      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()

      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, "v1,whatever")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts with 401 when webhook secret has invalid base64 after stripping whsec_ prefix" do
      Application.put_env(:klass_hero, :resend_webhook_secret, "whsec_NOT!!VALID==BASE64!!")

      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()

      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, "v1,whatever")
        |> VerifyWebhookSignature.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "strips whsec_ prefix from secret before base64 decoding", %{secret_bytes: secret_bytes} do
      svix_id = "msg_#{System.unique_integer([:positive])}"
      svix_timestamp = current_timestamp()
      sig = compute_signature(secret_bytes, svix_id, svix_timestamp, @raw_body)

      # The secret is already stored as "whsec_<base64>" in setup
      # This test verifies that the prefix is correctly stripped (not decoded as part of base64)
      conn =
        base_conn()
        |> add_svix_headers(svix_id, svix_timestamp, "v1,#{sig}")
        |> VerifyWebhookSignature.call([])

      refute conn.halted
    end
  end
end
