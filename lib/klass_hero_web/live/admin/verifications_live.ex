defmodule KlassHeroWeb.Admin.VerificationsLive do
  @moduledoc """
  LiveView for admin verification document management.

  Displays pending verification documents and allows admins to
  approve or reject provider verification requests.
  """

  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Verifications"))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-bold">{gettext("Verifications")}</h1>
      <p class="text-gray-600">{gettext("Admin verification management coming soon.")}</p>
    </div>
    """
  end
end
