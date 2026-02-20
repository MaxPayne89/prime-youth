defmodule KlassHeroWeb.HomeLiveTest do
  use KlassHeroWeb.FeatureCase, async: true

  import Phoenix.LiveViewTest

  describe "home page" do
    test "renders hero section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h1", "Heroes for Our Youth")
    end

    test "renders search bar in hero section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "input[placeholder='Search for programs...']")
      assert has_element?(view, "button", "Search")
    end

    test "renders trending tags", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "span", "Trending in Berlin:")
      assert has_element?(view, "button", "Swimming")
      assert has_element?(view, "button", "Math Tutor")
      assert has_element?(view, "button", "Summer Camp")
      assert has_element?(view, "button", "Piano")
      assert has_element?(view, "button", "Soccer")
    end

    test "search form submission navigates to programs page with query", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#home-search-form", %{search: "piano lessons"})
      |> render_submit()

      assert_redirect(view, "/programs?q=piano+lessons")
    end

    test "empty search does not navigate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#home-search-form", %{search: "  "})
      |> render_submit()

      refute_redirected(view, "/programs")
    end

    test "clicking trending tag navigates to programs page with tag query", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button[phx-value-tag='Swimming']")
      |> render_click()

      assert_redirect(view, "/programs?q=Swimming")
    end

    test "clicking different trending tag navigates correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button[phx-value-tag='Math Tutor']")
      |> render_click()

      assert_redirect(view, "/programs?q=Math+Tutor")
    end

    test "renders featured programs section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#featured-programs-section")
      assert has_element?(view, "h2", "Featured Programs")
      assert has_element?(view, "#featured-programs")
    end

    test "renders featured programs with stream", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify the stream container exists with proper attributes
      assert has_element?(view, "#featured-programs[phx-update='stream']")
    end

    test "renders view all programs button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "button", "View All Programs")
    end

    test "renders why klass hero section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#why-klass-hero-section")
      assert has_element?(view, "h2", "Why Klass Hero?")
    end

    test "renders why klass hero feature cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h3", "Safety First")
      assert has_element?(view, "h3", "Easy Scheduling")
      assert has_element?(view, "h3", "Community Focused")
    end

    test "navigates to programs page on explore click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Trigger the explore_programs event
      assert view
             |> element("button", "View All Programs")
             |> render_click()

      # Verify navigation occurred
      assert_redirect(view, ~p"/programs")
    end

    test "renders grow your passion business section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#grow-passion-business-section")
      assert has_element?(view, "h2", "Grow Your Passion Business")
      assert has_element?(view, "button", "Start Teaching Today")

      # Verify 3 step cards
      assert has_element?(view, "h3", "Create a Program")
      assert has_element?(view, "h3", "Deliver Quality")
      assert has_element?(view, "h3", "Get Paid & Grow")
    end

    @tag {:skip, "Pricing section hidden until transactions are live (#178)"}
    test "renders pricing section with family plans by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#pricing-section")
      assert has_element?(view, "h2", "Simple, Transparent Pricing")

      # Verify family plans are visible
      assert has_element?(view, "h3", "Explorer Family")
      assert has_element?(view, "h3", "Active Family")
    end

    @tag {:skip, "Pricing section hidden until transactions are live (#178)"}
    test "switches to provider pricing tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Click provider tab
      view
      |> element("button", "For Providers")
      |> render_click()

      # Verify provider plans are now visible
      assert has_element?(view, "h3", "Starter Provider")
      assert has_element?(view, "h3", "Pro Provider")
    end

    @tag {:skip, "Pricing section hidden until transactions are live (#178)"}
    test "switches back to family pricing tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Click provider tab first
      view
      |> element("button", "For Providers")
      |> render_click()

      # Click family tab
      view
      |> element("button", "For Families")
      |> render_click()

      # Verify family plans are visible again
      assert has_element?(view, "h3", "Explorer Family")
      assert has_element?(view, "h3", "Active Family")
    end

    test "renders founder section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#founder-section")
      assert has_element?(view, "h2", "Built by Parents to Empower Educators.")
      assert has_element?(view, "#founder-section a[href='/about']", "Read our founding story")
    end

    test "renders faq section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#faq-section")
      assert has_element?(view, "h2", "Frequently Asked Questions")

      # Verify all 5 FAQ questions exist
      assert has_element?(view, "button", "How does the 4-step provider vetting process work?")
      assert has_element?(view, "button", "Is there a free trial for the Active Family plan?")
      assert has_element?(view, "button", "Can I cancel a booking?")
      assert has_element?(view, "button", "Do you offer programs for adults?")
      assert has_element?(view, "button", "What are Klass Points?")
    end

    test "faq items have correct structure for client-side toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify FAQ items have unique IDs for answer and chevron elements
      # Note: The button itself doesn't have an ID, only the chevron and answer divs
      assert has_element?(view, "#faq-1-answer")
      assert has_element?(view, "#faq-1-chevron")

      assert has_element?(view, "#faq-2-answer")
      assert has_element?(view, "#faq-2-chevron")

      assert has_element?(view, "#faq-3-answer")
      assert has_element?(view, "#faq-3-chevron")

      assert has_element?(view, "#faq-4-answer")
      assert has_element?(view, "#faq-4-chevron")

      assert has_element?(view, "#faq-5-answer")
      assert has_element?(view, "#faq-5-chevron")
    end

    @tag {:skip, "Pricing section hidden until transactions are live (#178)"}
    test "family pricing cards show all expected features", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Explorer Family features
      assert has_element?(view, "li", "Browse all programs")
      assert has_element?(view, "li", "Book up to 2 activities per month")
      assert has_element?(view, "li", "Read and write reviews")
      assert has_element?(view, "li", "Join the community")

      # Active Family features
      assert has_element?(view, "li", "AI Support Bot for recommendations")
      assert has_element?(view, "li", "Unlimited bookings")
      assert has_element?(view, "li", "Progress tracking dashboard")
      assert has_element?(view, "li", "Direct messaging with providers")
      assert has_element?(view, "li", "1 free cancellation per month")
    end

    @tag {:skip, "Pricing section hidden until transactions are live (#178)"}
    test "provider pricing cards show all expected features", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Switch to provider tab
      view
      |> element("button", "For Providers")
      |> render_click()

      # Starter Provider features
      assert has_element?(view, "li", "Basic profile page")
      assert has_element?(view, "li", "List up to 3 programs")
      assert has_element?(view, "li", "Accept bookings")
      assert has_element?(view, "li", "Basic analytics")

      # Pro Provider features
      assert has_element?(view, "li", "Unlimited program listings")
      assert has_element?(view, "li", "Advanced analytics dashboard")
      assert has_element?(view, "li", "Priority customer support")
      assert has_element?(view, "li", "Featured placement opportunities")
    end

    @tag {:skip, "Pricing section hidden until transactions are live (#178)"}
    test "pricing tab defaults to families on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify families tab is active (has gradient styling)
      # We check for the presence of family plans
      assert has_element?(view, "h3", "Explorer Family")
      assert has_element?(view, "h3", "Active Family")
      refute has_element?(view, "h3", "Starter Provider")
      refute has_element?(view, "h3", "Pro Provider")
    end

    @tag {:skip, "Pricing section hidden until transactions are live (#178)"}
    test "pricing tab assign updates when switching tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Initial state: families
      assert has_element?(view, "h3", "Explorer Family")

      # Click provider tab
      view
      |> element("button", "For Providers")
      |> render_click()

      # Verify provider plans now visible
      assert has_element?(view, "h3", "Starter Provider")
      assert has_element?(view, "h3", "Pro Provider")
      refute has_element?(view, "h3", "Explorer Family")

      # Click families tab again
      view
      |> element("button", "For Families")
      |> render_click()

      # Verify family plans back
      assert has_element?(view, "h3", "Explorer Family")
      assert has_element?(view, "h3", "Active Family")
      refute has_element?(view, "h3", "Starter Provider")
    end

    test "featured programs stream container is properly configured", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Section heading renders
      assert has_element?(view, "#featured-programs-section")
      assert has_element?(view, "h2", "Featured Programs")

      # Stream container exists with correct phx-update attribute
      assert has_element?(view, "#featured-programs[phx-update='stream']")

      # Verify stream is used for rendering programs
      # The :for comprehension in the template uses @streams.featured_programs
      # We can verify the stream is working by checking for the grid container
      html = render(view)
      assert html =~ ~r/id="featured-programs"/
      assert html =~ ~r/phx-update="stream"/

      # View All Programs button present
      assert has_element?(view, "button", "View All Programs")
    end

    test "clicking featured program card navigates to program detail", %{conn: conn} do
      # Insert a program into the database
      program = insert(:program_schema)

      {:ok, view, _html} = live(conn, ~p"/")

      # Click the program card with the program-id attribute
      view
      |> element("[phx-click='view_program'][phx-value-program-id='#{program.id}']")
      |> render_click()

      # Should redirect to program detail page
      assert_redirect(view, ~p"/programs/#{program.id}")
    end
  end
end
