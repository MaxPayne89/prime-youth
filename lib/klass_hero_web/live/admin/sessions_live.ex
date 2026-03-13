defmodule KlassHeroWeb.Admin.SessionsLive do
  @moduledoc """
  Admin LiveView for session attendance management.

  Stub module — full implementation provided in the sessions admin task.
  """

  use KlassHeroWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div>Sessions admin coming soon.</div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
