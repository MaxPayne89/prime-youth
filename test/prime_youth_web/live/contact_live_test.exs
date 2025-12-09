defmodule PrimeYouthWeb.ContactLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "ContactLive" do
    test "renders contact page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      assert has_element?(view, "h1", "Contact Us")
      assert has_element?(view, "#contact-form")
    end

    test "displays contact information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contact")

      assert html =~ "support@primeyouth.com"
      assert html =~ "+1 (555) 123-4567"
      assert html =~ "123 Youth Avenue, Suite 100"
    end

    test "displays office hours", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contact")

      assert html =~ "Monday - Friday"
      assert html =~ "9:00 AM - 6:00 PM"
      assert html =~ "Saturday"
      assert html =~ "10:00 AM - 4:00 PM"
      assert html =~ "Sunday"
      assert html =~ "Closed"
    end

    test "validates required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "",
          "email" => "",
          "subject" => "",
          "message" => ""
        }
      })

      html = render(view)
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "validates name length constraints", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "A",
          "email" => "test@example.com",
          "subject" => "general",
          "message" => "This is a test message with enough characters"
        }
      })

      html = render(view)
      assert html =~ "should be at least 2 character"

      long_name = String.duplicate("A", 101)

      render_change(view, "validate", %{
        "contact" => %{
          "name" => long_name,
          "email" => "test@example.com",
          "subject" => "general",
          "message" => "This is a test message with enough characters"
        }
      })

      html = render(view)
      assert html =~ "should be at most 100 character"
    end

    test "validates email format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "invalid-email",
          "subject" => "general",
          "message" => "This is a test message with enough characters"
        }
      })

      html = render(view)
      assert html =~ "must be a valid email address"
    end

    test "validates message length constraints", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "subject" => "general",
          "message" => "Short"
        }
      })

      html = render(view)
      assert html =~ "should be at least 10 character"

      long_message = String.duplicate("A", 1001)

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "subject" => "general",
          "message" => long_message
        }
      })

      html = render(view)
      assert html =~ "should be at most 1000 character"
    end

    test "validates subject is from allowed options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "subject" => "invalid_subject",
          "message" => "This is a test message with enough characters"
        }
      })

      html = render(view)
      assert html =~ "is invalid"
    end

    test "accepts valid form submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_submit(view, "submit", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "subject" => "general",
          "message" => "This is a test message with enough characters to pass validation"
        }
      })

      html = render(view)
      assert html =~ "Message sent successfully!"

      assert html =~ "We&#39;ll get back to you within 24 hours" or
               html =~ "We'll get back to you within 24 hours"
    end

    test "resets form after successful submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_submit(view, "submit", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "subject" => "general",
          "message" => "This is a test message with enough characters to pass validation"
        }
      })

      html = render(view)
      refute html =~ "value=\"John Doe\""
      refute html =~ "value=\"john@example.com\""
    end

    test "displays validation errors on submit with invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_submit(view, "submit", %{
        "contact" => %{
          "name" => "A",
          "email" => "invalid",
          "subject" => "general",
          "message" => "Short"
        }
      })

      html = render(view)
      assert html =~ "should be at least 2 character" or html =~ "should be at least 10 character"
      refute html =~ "Message sent successfully!"
    end

    test "allows all valid subject options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      valid_subjects = ~w(general program booking instructor technical other)

      for subject <- valid_subjects do
        render_change(view, "validate", %{
          "contact" => %{
            "name" => "John Doe",
            "email" => "john@example.com",
            "subject" => subject,
            "message" => "This is a test message with enough characters"
          }
        })

        html = render(view)
        refute html =~ "is invalid"
      end
    end

    test "real-time validation updates as user types", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "invalid",
          "subject" => "general",
          "message" => "This is a test message"
        }
      })

      html = render(view)
      assert html =~ "must be a valid email address"

      render_change(view, "validate", %{
        "contact" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "subject" => "general",
          "message" => "This is a test message"
        }
      })

      html = render(view)
      refute html =~ "must be a valid email address"
    end
  end
end
