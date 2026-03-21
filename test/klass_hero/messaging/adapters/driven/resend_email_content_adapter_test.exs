defmodule KlassHero.Messaging.Adapters.Driven.ResendEmailContentAdapterTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Adapters.Driven.ResendEmailContentAdapter

  setup do
    Req.Test.stub(ResendEmailContentAdapter, fn conn ->
      case conn.path_info do
        ["emails", "receiving", "success-id"] ->
          Req.Test.json(conn, %{
            "html" => "<p>Hello</p>",
            "text" => "Hello",
            "headers" => %{"Message-ID" => "<abc@example.com>"}
          })

        ["emails", "receiving", "not-found-id"] ->
          conn
          |> Plug.Conn.put_status(404)
          |> Req.Test.json(%{"message" => "Not found"})

        ["emails", "receiving", "rate-limited-id"] ->
          conn
          |> Plug.Conn.put_status(429)
          |> Req.Test.json(%{"message" => "Rate limited"})

        ["emails", "receiving", "server-error-id"] ->
          conn
          |> Plug.Conn.put_status(500)
          |> Req.Test.json(%{"message" => "Internal error"})
      end
    end)

    :ok
  end

  describe "fetch_content/1" do
    test "returns content on success with normalized headers" do
      assert {:ok, content} = ResendEmailContentAdapter.fetch_content("success-id")
      assert content.html == "<p>Hello</p>"
      assert content.text == "Hello"
      assert content.headers == [%{"name" => "Message-ID", "value" => "<abc@example.com>"}]
    end

    test "returns :not_found on 404" do
      assert {:error, :not_found} = ResendEmailContentAdapter.fetch_content("not-found-id")
    end

    test "returns :rate_limited on 429" do
      assert {:error, :rate_limited} = ResendEmailContentAdapter.fetch_content("rate-limited-id")
    end

    test "returns :server_error on 5xx" do
      assert {:error, :server_error} = ResendEmailContentAdapter.fetch_content("server-error-id")
    end
  end
end
