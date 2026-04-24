defmodule KlassHeroWeb.Provider.IncidentReportLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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
end
