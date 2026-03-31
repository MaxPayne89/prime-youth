defmodule KlassHero.Shared.Tracing.PlugTest do
  use ExUnit.Case, async: false
  use KlassHero.TracingHelpers

  import Plug.Conn
  import Plug.Test

  alias KlassHero.Shared.Tracing.Plug, as: TracingPlug

  # Drain any spans left in the mailbox from previous tests before each test.
  # Necessary because OTel uses a global singleton exporter and async: false
  # does not isolate the process mailbox between tests.
  setup do
    flush_spans()
    drain_spans()
    :ok
  end

  defp drain_spans do
    receive do
      {:span, _} -> drain_spans()
    after
      0 -> :ok
    end
  end

  defp collect_spans(timeout \\ 500) do
    receive do
      {:span, s} -> [s | collect_spans(timeout)]
    after
      timeout -> []
    end
  end

  defp find_span(spans, name) do
    Enum.find(spans, fn s -> span(s, :name) == name end)
  end

  defp run_plug(conn) do
    opts = TracingPlug.init([])
    TracingPlug.call(conn, opts)
  end

  describe "creates root span for HTTP requests" do
    test "span name uses method and request path when no route pattern available" do
      _conn =
        conn(:get, "/programs")
        |> run_plug()
        |> send_resp(200, "OK")

      flush_spans()
      spans = collect_spans()

      assert find_span(spans, "HTTP GET /programs") != nil
    end

    test "span name uses method and route pattern when available" do
      _conn =
        conn(:get, "/programs/123")
        |> put_private(:plug_route, {"/programs/:id", fn _ -> nil end})
        |> run_plug()
        |> send_resp(200, "OK")

      flush_spans()
      spans = collect_spans()

      assert find_span(spans, "HTTP GET /programs/:id") != nil,
             "Expected span 'HTTP GET /programs/:id', got: #{inspect(Enum.map(spans, &span(&1, :name)))}"
    end

    test "sets http.method attribute" do
      _conn =
        conn(:post, "/programs")
        |> run_plug()
        |> send_resp(201, "Created")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP POST /programs")
      assert http_span != nil

      attrs = span_attributes(http_span)
      assert attrs["http.method"] == "POST"
    end

    test "sets http.target attribute to request path" do
      _conn =
        conn(:get, "/programs/abc")
        |> run_plug()
        |> send_resp(200, "OK")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP GET /programs/abc")
      assert http_span != nil

      attrs = span_attributes(http_span)
      assert attrs["http.target"] == "/programs/abc"
    end

    test "sets http.route attribute when route pattern is available" do
      _conn =
        conn(:get, "/programs/abc")
        |> put_private(:plug_route, {"/programs/:id", fn _ -> nil end})
        |> run_plug()
        |> send_resp(200, "OK")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP GET /programs/:id")
      assert http_span != nil

      attrs = span_attributes(http_span)
      assert attrs["http.route"] == "/programs/:id"
    end
  end

  describe "sets http.status_code on response" do
    test "records 200 status code" do
      _conn =
        conn(:get, "/programs")
        |> run_plug()
        |> send_resp(200, "OK")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP GET /programs")
      assert http_span != nil

      attrs = span_attributes(http_span)
      assert attrs["http.status_code"] == 200
    end

    test "records 404 status code" do
      _conn =
        conn(:get, "/unknown")
        |> run_plug()
        |> send_resp(404, "Not Found")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP GET /unknown")
      assert http_span != nil

      attrs = span_attributes(http_span)
      assert attrs["http.status_code"] == 404
    end
  end

  describe "sets error status for 5xx responses" do
    test "sets span status to error for 500" do
      _conn =
        conn(:get, "/programs")
        |> run_plug()
        |> send_resp(500, "Internal Server Error")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP GET /programs")
      assert http_span != nil

      assert span_status_code(http_span) == :error
    end

    test "sets span status to error for 503" do
      _conn =
        conn(:get, "/programs")
        |> run_plug()
        |> send_resp(503, "Service Unavailable")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP GET /programs")
      assert http_span != nil

      assert span_status_code(http_span) == :error
    end

    test "does not set error status for 4xx responses" do
      _conn =
        conn(:get, "/missing")
        |> run_plug()
        |> send_resp(404, "Not Found")

      flush_spans()
      spans = collect_spans()
      http_span = find_span(spans, "HTTP GET /missing")
      assert http_span != nil, "Expected span 'HTTP GET /missing' to be exported"

      # When no error status is set, span(:status) returns :undefined (OTel default).
      # Only a span explicitly set to :error is a failure — :undefined and :ok are fine.
      raw_status = span(http_span, :status)
      assert raw_status == :undefined or span_status_code(http_span) != :error
    end
  end
end
