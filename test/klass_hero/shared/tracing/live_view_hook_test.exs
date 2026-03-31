defmodule KlassHero.Shared.Tracing.LiveViewHookTest do
  use ExUnit.Case, async: false
  use KlassHero.TracingHelpers

  alias KlassHero.Shared.Tracing.LiveViewHook

  # Drain any spans left in the mailbox from previous tests before each test.
  # Necessary because OTel uses a global singleton exporter and async: false
  # does not isolate the process mailbox between tests.
  #
  # Two rounds of flush+drain ensure spans that arrive asynchronously after the
  # first flush are also cleared before the test begins.
  setup do
    flush_spans()
    drain_spans()
    flush_spans()
    drain_spans()
    :ok
  end

  defp drain_spans do
    receive do
      {:span, _} -> drain_spans()
    after
      50 -> :ok
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

  defp connected_socket(view_module, live_action \\ :index) do
    %Phoenix.LiveView.Socket{
      transport_pid: self(),
      view: view_module,
      assigns: %{__changed__: %{}, live_action: live_action}
    }
  end

  defp disconnected_socket(view_module, live_action \\ :index) do
    %Phoenix.LiveView.Socket{
      transport_pid: nil,
      view: view_module,
      assigns: %{__changed__: %{}, live_action: live_action}
    }
  end

  describe "on connected mount" do
    test "creates a span named from the view module" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      flush_spans()
      spans = collect_spans()

      assert find_span(spans, "LiveView.mount DashboardLive") != nil,
             "Expected span 'LiveView.mount DashboardLive', got: #{inspect(Enum.map(spans, &span(&1, :name)))}"
    end

    test "span name strips KlassHeroWeb and KlassHero noise segments" do
      socket = connected_socket(KlassHeroWeb.Provider.ProgramLive.Index)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      flush_spans()
      spans = collect_spans()

      assert find_span(spans, "LiveView.mount Provider.ProgramLive.Index") != nil,
             "Expected span 'LiveView.mount Provider.ProgramLive.Index', got: #{inspect(Enum.map(spans, &span(&1, :name)))}"
    end

    test "sets liveview.module attribute" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      flush_spans()
      spans = collect_spans()
      lv_span = find_span(spans, "LiveView.mount DashboardLive")
      assert lv_span != nil

      attrs = span_attributes(lv_span)
      assert attrs["liveview.module"] == "DashboardLive"
    end

    test "sets liveview.action attribute from socket assigns" do
      socket = connected_socket(KlassHeroWeb.DashboardLive, :show)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      flush_spans()
      spans = collect_spans()
      lv_span = find_span(spans, "LiveView.mount DashboardLive")
      assert lv_span != nil

      attrs = span_attributes(lv_span)
      assert attrs["liveview.action"] == "show"
    end

    test "returns {:cont, socket} unchanged" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      assert {:cont, ^socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)
    end

    test "span ends after mount completes (not kept open)" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      flush_spans()
      spans = collect_spans()

      # If span was still open it wouldn't be exported yet — finding it confirms it's ended
      assert find_span(spans, "LiveView.mount DashboardLive") != nil
    end
  end

  describe "on disconnected mount (static render)" do
    test "does not create a span" do
      socket = disconnected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      flush_spans()
      spans = collect_spans()

      assert find_span(spans, "LiveView.mount DashboardLive") == nil,
             "Expected no span on disconnected mount, but found one"
    end

    test "returns {:cont, socket} unchanged" do
      socket = disconnected_socket(KlassHeroWeb.DashboardLive)
      assert {:cont, ^socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)
    end
  end
end
