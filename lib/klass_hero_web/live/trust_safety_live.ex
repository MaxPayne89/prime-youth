defmodule KlassHeroWeb.TrustSafetyLive do
  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Trust & Safety"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <h1>TRUST & SAFETY</h1>
    </div>
    """
  end
end
