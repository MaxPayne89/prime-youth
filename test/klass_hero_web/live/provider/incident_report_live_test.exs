defmodule KlassHeroWeb.Provider.IncidentReportLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.IncidentReportSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProgramProjectionSchema
  alias KlassHero.Repo

  defp insert_provider_program!(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      program_id: Ecto.UUID.generate(),
      provider_id: attrs[:provider_id],
      name: "Some Program",
      status: "active",
      inserted_at: now,
      updated_at: now
    }

    Repo.insert!(struct(ProviderProgramProjectionSchema, Map.merge(defaults, attrs)))
  end

  # Trigger: a submit test needs both the projection (for ownership check) and
  #          the underlying programs row (for the incident_reports.program_id FK)
  # Why: SubmitIncidentReport queries the projection but persists into incident_reports
  #      which references programs(:id) — both must exist with matching ids
  # Outcome: returns the program_id that ties projection + programs row together
  defp insert_owned_program!(provider_id, name) do
    row = insert_provider_program!(%{provider_id: provider_id, name: name})
    insert(:program_schema, id: row.program_id, provider_id: provider_id)
    row.program_id
  end

  describe "mount" do
    setup :register_and_log_in_provider

    test "renders the form heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/provider/incidents/new")
      assert html =~ "Report an Incident"
    end

    test "preselects a program when ?program_id= is valid", %{conn: conn, provider: provider} do
      row = insert_provider_program!(%{provider_id: provider.id, name: "Robotics"})

      {:ok, view, _html} = live(conn, ~p"/provider/incidents/new?program_id=#{row.program_id}")

      assert has_element?(
               view,
               ~s|#incident-report-form[data-selected-program="#{row.program_id}"]|
             )
    end

    test "redirects with flash when program_id is not owned", %{conn: conn} do
      bogus_id = Ecto.UUID.generate()

      assert {:error, {:live_redirect, %{to: "/provider/dashboard", flash: flash}}} =
               live(conn, ~p"/provider/incidents/new?program_id=#{bogus_id}")

      assert flash["error"] =~ "not found"
    end
  end

  describe "form rendering" do
    setup [:register_and_log_in_provider]

    test "renders all required fields", %{conn: conn, provider: provider} do
      _ = insert_provider_program!(%{provider_id: provider.id, name: "Robotics"})
      {:ok, _view, html} = live(conn, ~p"/provider/incidents/new")

      assert html =~ ~s|name="incident[occurred_at]"|
      assert html =~ ~s|name="incident[program_id]"|
      assert html =~ ~s|name="incident[category]"|
      assert html =~ ~s|name="incident[severity]"|
      assert html =~ ~s|name="incident[description]"|
      assert html =~ "Safety Concern"
      assert html =~ "Critical"
    end

    test "renders the drag-drop photo uploader", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/incidents/new")
      assert has_element?(view, "[phx-drop-target]")
      assert has_element?(view, ~s|input[type="file"][name^="photo"]|)
    end
  end

  describe "submit" do
    setup [:register_and_log_in_provider]

    test "successful submit redirects to dashboard with flash", %{conn: conn, provider: provider} do
      program_id = insert_owned_program!(provider.id, "Robotics")

      {:ok, view, _html} = live(conn, ~p"/provider/incidents/new?program_id=#{program_id}")

      view
      |> form("#incident-report-form",
        incident: %{
          "program_id" => program_id,
          "category" => "safety_concern",
          "severity" => "medium",
          "description" => "A child tripped but was not injured.",
          "occurred_at" => "2026-04-22T14:00"
        }
      )
      |> render_submit()

      {path, flash} = assert_redirect(view)
      assert path == "/provider/dashboard"
      assert flash["info"] =~ "submitted"
      assert Repo.aggregate(IncidentReportSchema, :count) == 1
    end

    test "invalid submit (description too short) renders inline errors", %{
      conn: conn,
      provider: provider
    } do
      program_id = insert_owned_program!(provider.id, "Robotics")

      {:ok, view, _html} = live(conn, ~p"/provider/incidents/new?program_id=#{program_id}")

      html =
        view
        |> form("#incident-report-form",
          incident: %{
            "program_id" => program_id,
            "category" => "safety_concern",
            "severity" => "medium",
            "description" => "short",
            "occurred_at" => "2026-04-22T14:00"
          }
        )
        |> render_submit()

      assert html =~ "at least 10"
      assert Repo.aggregate(IncidentReportSchema, :count) == 0
    end
  end
end
