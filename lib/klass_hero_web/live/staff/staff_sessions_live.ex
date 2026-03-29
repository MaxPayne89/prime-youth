defmodule KlassHeroWeb.Staff.StaffSessionsLive do
  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("My Sessions"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="staff-sessions">
      <h1>{gettext("My Sessions")}</h1>
    </div>
    """
  end
end
