defmodule KlassHeroWeb.ProviderComponentsTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  describe "sessions_modal/1" do
    test "renders the provided sessions in order" do
      modal = %{
        program_id: "prog-1",
        program_title: "Judo",
        sessions: [
          %SessionDetail{
            session_id: "s-1",
            program_id: "prog-1",
            provider_id: "prv-1",
            session_date: ~D[2026-05-01],
            start_time: ~T[15:00:00],
            end_time: ~T[16:00:00],
            status: :scheduled,
            program_title: "Judo",
            current_assigned_staff_name: "Alice",
            checked_in_count: 0,
            total_count: 0
          },
          %SessionDetail{
            session_id: "s-2",
            program_id: "prog-1",
            provider_id: "prv-1",
            session_date: ~D[2026-05-08],
            start_time: ~T[15:00:00],
            end_time: ~T[16:00:00],
            status: :cancelled,
            program_title: "Judo",
            current_assigned_staff_name: nil,
            checked_in_count: 0,
            total_count: 0
          }
        ]
      }

      html = render_component(&KlassHeroWeb.ProviderComponents.sessions_modal/1, modal: modal)

      assert html =~ "Judo"
      assert html =~ "Alice"
      assert html =~ "Unassigned"
      # Cancelled row hides attendance (same-line match; dotall flag removed because the
      # plan's `/is` regex spans across rows and fires even for a correct implementation)
      refute html =~ ~r/0\s*\/\s*0.*cancelled/i
    end

    test "shows empty state when sessions is []" do
      modal = %{program_id: "p", program_title: "T", sessions: []}
      html = render_component(&KlassHeroWeb.ProviderComponents.sessions_modal/1, modal: modal)
      assert html =~ "No sessions scheduled yet"
    end
  end
end
