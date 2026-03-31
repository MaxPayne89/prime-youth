defmodule KlassHero.Shared.Tracing.Plug do
  @moduledoc """
  A Plug that creates a root OpenTelemetry span for each HTTP request.

  Span name is derived from the route pattern (low-cardinality) when available,
  e.g. `"HTTP GET /programs/:id"`. Falls back to the request path when the
  Phoenix router has not yet matched a route.

  Attributes set on the span:
  - `http.method`  — the HTTP verb (GET, POST, …)
  - `http.target`  — the request path (high-cardinality; use for debugging)
  - `http.route`   — the route pattern, only when available
  - `http.status_code` — set via `register_before_send`, after the response is sent

  Spans for 5xx responses are marked with `:error` status.

  ## Usage

  Add to your endpoint or router pipeline:

      plug KlassHero.Shared.Tracing.Plug

  The plug must run before the Phoenix router so that spans from adapters
  called deeper in the pipeline nest automatically under this root span via
  OTel's process-dictionary context.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    tracer = :opentelemetry.get_application_tracer(__MODULE__)
    span_name = build_span_name(conn)

    span_ctx = :otel_tracer.start_span(:otel_ctx.get_current(), tracer, span_name, %{})

    new_ctx = OpenTelemetry.Tracer.set_current_span(:otel_ctx.get_current(), span_ctx)
    token = :otel_ctx.attach(new_ctx)

    OpenTelemetry.Span.set_attribute(span_ctx, "http.method", conn.method)
    OpenTelemetry.Span.set_attribute(span_ctx, "http.target", conn.request_path)

    case route_pattern(conn) do
      nil -> :ok
      pattern -> OpenTelemetry.Span.set_attribute(span_ctx, "http.route", pattern)
    end

    register_before_send(conn, fn conn ->
      OpenTelemetry.Span.set_attribute(span_ctx, "http.status_code", conn.status)

      if conn.status >= 500 do
        OpenTelemetry.Span.set_status(span_ctx, :error)
      end

      OpenTelemetry.Span.end_span(span_ctx)
      :otel_ctx.detach(token)

      conn
    end)
  end

  defp route_pattern(conn) do
    case conn.private[:plug_route] do
      {pattern, _fun} -> pattern
      nil -> nil
    end
  end

  defp build_span_name(conn) do
    case route_pattern(conn) do
      nil -> "HTTP #{conn.method} #{conn.request_path}"
      pattern -> "HTTP #{conn.method} #{pattern}"
    end
  end
end
