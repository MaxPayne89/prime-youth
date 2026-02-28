defmodule KlassHeroWeb.BookingLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "BookingLive authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      program = insert(:program_schema)
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/programs/#{program.id}/booking")

      # Should redirect to login page
      assert path == ~p"/users/log-in"
    end

    test "renders booking page when authenticated with valid program", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      program = insert(:program_schema, title: "Creative Art World")

      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      assert has_element?(view, "h1", "Enrollment")
      assert render(view) =~ "Creative Art World"
    end
  end

  describe "BookingLive mount validation" do
    setup :register_and_log_in_user

    test "redirects with error flash for invalid program ID format", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/programs/invalid/booking")

      assert path == ~p"/programs"
      # Invalid UUIDs return :not_found, which shows the "not found" message
      assert flash["error"] == "Program not found"
    end

    test "redirects with error flash for non-existent program ID", %{conn: conn} do
      # Use a valid UUID format that doesn't exist in database
      non_existent_uuid = "550e8400-e29b-41d4-a716-446655449999"

      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/programs/#{non_existent_uuid}/booking")

      assert path == ~p"/programs"
      assert flash["error"] == "Program not found"
    end

    test "redirects with error flash when program is full", %{conn: conn} do
      program = insert(:program_schema)

      # Set enrollment policy with max=1
      {:ok, _policy} =
        KlassHero.Enrollment.set_enrollment_policy(%{
          program_id: program.id,
          max_enrollment: 1
        })

      # Fill the single spot with an enrollment
      insert(:enrollment_schema, program_id: program.id, status: "pending")

      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/programs/#{program.id}/booking")

      assert path == ~p"/programs/#{program.id}"
      assert flash["error"] =~ "currently full"
    end

    test "renders normally when program has unlimited capacity", %{conn: conn} do
      program = insert(:program_schema, title: "Unlimited Spots Program")

      # No enrollment policy set — default is unlimited
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      assert has_element?(view, "h1", "Enrollment")
      assert render(view) =~ "Unlimited Spots Program"
    end
  end

  describe "BookingLive fee calculations" do
    setup :register_and_log_in_user

    test "displays correct fee breakdown for default program (card payment)", %{conn: conn} do
      # Factory default: price=100.00, no date range → 1 week
      # program_fee=100.00, registration=25.00, subtotal=125.00
      # VAT 19%=23.75, card_fee=2.50, total=151.25
      program = insert(:program_schema, price: Decimal.new("100.00"))
      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}/booking")

      assert html =~ "Program fee (1 weeks):"
      assert html =~ "€100.00"
      assert html =~ "€125.00"
      assert html =~ "VAT (19%):"
      assert html =~ "€23.75"
      assert html =~ "Credit card fee:"
      assert html =~ "€2.50"
      assert html =~ "€151.25"
    end

    test "switching to transfer removes card fee and updates total", %{conn: conn} do
      program = insert(:program_schema, price: Decimal.new("100.00"))
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      # Switch to bank transfer
      view
      |> element("[phx-click='select_payment_method'][phx-value-method='transfer']")
      |> render_click()

      html = render(view)

      # Card fee should be gone, total should be subtotal + VAT only
      # 125.00 + 23.75 = 148.75
      refute html =~ "Credit card fee"
      assert html =~ "€148.75"
    end

    test "multi-week program calculates correct program fee", %{conn: conn} do
      # 8-week program at €50/week → program_fee = 400.00
      # subtotal = 400.00 + 25.00 = 425.00
      # VAT = 425.00 * 0.19 = 80.75
      # card_fee = 2.50, total = 508.25
      program =
        insert(:program_schema,
          price: Decimal.new("50.00"),
          start_date: ~D[2026-03-01],
          end_date: ~D[2026-04-26]
        )

      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}/booking")

      assert html =~ "Program fee (8 weeks):"
      assert html =~ "€400.00"
      assert html =~ "€425.00"
      assert html =~ "€80.75"
      assert html =~ "€508.25"
    end
  end

  describe "BookingLive enrollment validation" do
    setup :register_and_log_in_user

    test "complete_enrollment with missing child_id shows error", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      html =
        view
        |> form("form[phx-submit='complete_enrollment']", %{
          "child_id" => "",
          "special_requirements" => "Test"
        })
        |> render_submit()

      assert html =~ "Please select a child for enrollment."
    end

    test "complete_enrollment with valid data shows success message", %{conn: conn, user: user} do
      # Create parent profile and child for the logged-in user
      parent = insert(:parent_schema, identity_id: user.id)
      {child, _parent} = insert_child_with_guardian(parent: parent, first_name: "Emma")

      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      view
      |> form("form[phx-submit='complete_enrollment']", %{
        "child_id" => child.id,
        "special_requirements" => "No allergies"
      })
      |> render_submit()

      assert_redirect(view, ~p"/dashboard")
    end

    test "back_to_program button navigates to program detail", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      view
      |> element("[phx-click='back_to_program']")
      |> render_click()

      assert_redirect(view, ~p"/programs/#{program.id}")
    end

    test "select_payment_method updates payment method and recalculates totals", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      # Initially card payment is selected
      html = render(view)
      assert html =~ "Credit card fee"

      # Switch to transfer payment
      view
      |> element("[phx-click='select_payment_method'][phx-value-method='transfer']")
      |> render_click()

      # Card fee should be removed
      html = render(view)
      refute html =~ "Credit card fee"
    end
  end
end
