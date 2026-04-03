defmodule KlassHero.Shared.Tracing.LiveViewHookTest do
  use ExUnit.Case, async: false
  use KlassHero.TracingHelpers

  alias KlassHero.Shared.Tracing.LiveViewHook
  alias KlassHeroWeb.Provider.ProgramLive.Index
  alias Phoenix.LiveView.Socket

  # Drain leftover spans between tests. Uses 0ms timeout so it returns
  # immediately when the mailbox is empty — no overhead.
  setup do
    flush_spans()
    drain_span_mailbox()
    :ok
  end

  defp drain_span_mailbox do
    receive do
      {:span, _} -> drain_span_mailbox()
    after
      10 -> :ok
    end
  end

  defp connected_socket(view_module, live_action \\ :index) do
    %Socket{
      transport_pid: self(),
      view: view_module,
      assigns: %{__changed__: %{}, live_action: live_action}
    }
  end

  defp disconnected_socket(view_module, live_action \\ :index) do
    %Socket{
      transport_pid: nil,
      view: view_module,
      assigns: %{__changed__: %{}, live_action: live_action}
    }
  end

  describe "on connected mount" do
    test "creates a span named from the view module" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      assert_span("LiveView.mount DashboardLive")
    end

    test "span name strips KlassHeroWeb and KlassHero noise segments" do
      socket = connected_socket(Index)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      assert_span("LiveView.mount Provider.ProgramLive.Index")
    end

    test "sets liveview.module attribute" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      assert_span("LiveView.mount DashboardLive", "liveview.module": "DashboardLive")
    end

    test "sets liveview.action attribute from socket assigns" do
      socket = connected_socket(KlassHeroWeb.DashboardLive, :show)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      assert_span("LiveView.mount DashboardLive", "liveview.action": "show")
    end

    test "returns {:cont, socket} unchanged" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      assert {:cont, ^socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)
    end

    test "span ends after mount completes (not kept open)" do
      socket = connected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      # If span was still open it wouldn't be exported yet — finding it confirms it's ended
      assert_span("LiveView.mount DashboardLive")
    end
  end

  describe "on disconnected mount (static render)" do
    test "does not create a span" do
      socket = disconnected_socket(KlassHeroWeb.DashboardLive)
      {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      flush_spans()

      receive do
        {:span, s} ->
          flunk("Expected no span, got: #{inspect(span(s, :name))}")
      after
        100 -> :ok
      end
    end

    test "returns {:cont, socket} unchanged" do
      socket = disconnected_socket(KlassHeroWeb.DashboardLive)
      assert {:cont, ^socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)
    end
  end
end
