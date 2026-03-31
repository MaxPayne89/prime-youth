defmodule KlassHero.Shared.Tracing.LiveViewHook do
  @moduledoc """
  A LiveView `on_mount` hook that creates a root OpenTelemetry span for connected mounts.

  Only creates a span on connected mounts (i.e. when `Phoenix.LiveView.connected?/1`
  returns `true`). Static/disconnected renders are skipped to avoid noise from the
  initial HTTP render, which is already covered by `KlassHero.Shared.Tracing.Plug`.

  Span name is derived from the socket's view module with noise segments stripped,
  e.g. `"LiveView.mount DashboardLive"` for `KlassHeroWeb.DashboardLive`.

  Attributes set on the span:
  - `liveview.module` — the formatted view name (noise stripped)
  - `liveview.action` — the `live_action` from socket assigns

  The span ends as soon as `on_mount/4` returns — it covers only the mount phase,
  not the full LiveView process lifetime.

  ## Usage

  Wire into every live session in the router:

      live_session :authenticated,
        on_mount: [{KlassHero.Shared.Tracing.LiveViewHook, :trace}] do
        # ...
      end
  """

  require Logger

  # Strips web-layer prefixes (KlassHeroWeb) — intentionally different from
  # the adapter-path segments stripped in KlassHero.Shared.Tracing.@noise_segments
  @noise_segments ~w[Elixir KlassHeroWeb KlassHero]

  @doc """
  LiveView `on_mount` callback. Hook name is `:trace`.

  Creates a root span on connected mounts and returns `{:cont, socket}` in all cases.
  Tracing failures are caught and logged — they never crash the mount.
  """
  def on_mount(:trace, _params, _session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      try do
        view_name = format_view_name(socket.view)
        span_name = "LiveView.mount #{view_name}"
        action = socket.assigns[:live_action]

        tracer = :opentelemetry.get_application_tracer(__MODULE__)

        :otel_tracer.with_span(tracer, span_name, %{}, fn _ctx ->
          OpenTelemetry.Tracer.set_attribute("liveview.module", view_name)
          OpenTelemetry.Tracer.set_attribute("liveview.action", to_string(action))
        end)
      rescue
        exception ->
          Logger.warning(
            "[Tracing.LiveViewHook] Failed to create span: #{Exception.message(exception)}",
            view: inspect(socket.view)
          )
      end
    end

    {:cont, socket}
  end

  defp format_view_name(view_module) do
    view_module
    |> Module.split()
    |> Enum.reject(&(&1 in @noise_segments))
    |> Enum.join(".")
  end
end
