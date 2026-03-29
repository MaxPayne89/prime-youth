defmodule KlassHeroWeb.Staff.StaffParticipationLive do
  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Manage Participation"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="staff-participation">
      <h1>{gettext("Manage Participation")}</h1>
    </div>
    """
  end
end
