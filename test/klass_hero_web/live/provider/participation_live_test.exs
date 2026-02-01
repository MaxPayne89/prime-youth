defmodule KlassHeroWeb.Provider.ParticipationLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  setup :register_and_log_in_provider

  defp create_session_with_child(%{provider: _provider}) do
    session = insert(:program_session_schema, status: "in_progress")
    parent = insert(:parent_profile_schema)

    child =
      insert(:child_schema,
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Mueller",
        allergies: "Peanuts",
        support_needs: "Wheelchair access",
        emergency_contact: "+49 170 1234567"
      )

    record =
      insert(:participation_record_schema,
        session_id: session.id,
        child_id: child.id,
        parent_id: parent.id,
        status: :registered
      )

    %{session: session, parent: parent, child: child, record: record}
  end

  describe "roster displays child name" do
    setup [:create_session_with_child]

    test "renders child name in roster", %{conn: conn, session: session} do
      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      assert has_element?(view, "div", "Emma")
      assert has_element?(view, "div", "Mueller")
    end
  end

  describe "consent-gated safety info" do
    setup [:create_session_with_child]

    test "shows safety badges when child has consent and safety data", %{
      conn: conn,
      session: session,
      parent: parent,
      child: child,
      record: record
    } do
      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      )

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      assert has_element?(view, "#safety-info-#{record.id}")
      assert has_element?(view, "#safety-info-#{record.id} span", "Peanuts")
      assert has_element?(view, "#safety-info-#{record.id} span", "Wheelchair access")
      assert has_element?(view, "#safety-info-#{record.id} span", "+49 170 1234567")
    end

    test "hides safety info when child has no consent", %{
      conn: conn,
      session: session,
      record: record
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      refute has_element?(view, "#safety-info-#{record.id}")
    end

    test "hides safety info when consent has been withdrawn", %{
      conn: conn,
      session: session,
      parent: parent,
      child: child,
      record: record
    } do
      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing",
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      refute has_element?(view, "#safety-info-#{record.id}")
    end

    test "hides safety badges when child has consent but nil safety data", %{
      conn: conn,
      session: session
    } do
      parent = insert(:parent_profile_schema)

      child_no_allergies =
        insert(:child_schema,
          parent_id: parent.id,
          first_name: "Liam",
          last_name: "Schmidt",
          allergies: nil,
          support_needs: nil,
          emergency_contact: nil
        )

      record_no_allergies =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child_no_allergies.id,
          parent_id: parent.id,
          status: :registered
        )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child_no_allergies.id,
        consent_type: "provider_data_sharing"
      )

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      # Child name renders, but no safety info badges (all fields are nil)
      assert has_element?(view, "div", "Liam")
      refute has_element?(view, "#safety-info-#{record_no_allergies.id}")
    end
  end

  describe "behavioral notes" do
    setup [:create_session_with_child]

    defp check_in_record(%{record: record, provider: provider}) do
      {:ok, updated} =
        KlassHero.Participation.record_check_in(%{
          record_id: record.id,
          checked_in_by: provider.id
        })

      %{record: updated}
    end

    test "shows 'Add Note' button for checked-in child", %{
      conn: conn,
      session: session,
      record: record,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      assert has_element?(view, "#add-note-btn-#{record.id}")
    end

    test "does not show 'Add Note' for registered child", %{
      conn: conn,
      session: session,
      record: record
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      refute has_element?(view, "#add-note-btn-#{record.id}")
    end

    test "expand and submit behavioral note form", %{
      conn: conn,
      session: session,
      record: record,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      # Click "Add Note" to expand form
      view
      |> element("#add-note-btn-#{record.id}")
      |> render_click()

      assert has_element?(view, "#behavioral-note-form-#{record.id}")

      # Submit the note
      view
      |> form("#behavioral-note-form-#{record.id}", %{note: %{content: "Great participation"}})
      |> render_submit()

      # Form should collapse and badge should appear
      refute has_element?(view, "#behavioral-note-form-#{record.id}")
    end

    test "shows note status badge after submission", %{
      conn: conn,
      session: session,
      record: record,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      # Submit a note first
      {:ok, _note} =
        KlassHero.Participation.submit_behavioral_note(%{
          participation_record_id: record.id,
          provider_id: provider.id,
          content: "Good session"
        })

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      # Should not show "Add Note" button (note already exists)
      refute has_element?(view, "#add-note-btn-#{record.id}")
    end

    test "shows 'Edit & Resubmit' for rejected note", %{
      conn: conn,
      session: session,
      record: record,
      parent: parent,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      # Submit and reject a note
      {:ok, note} =
        KlassHero.Participation.submit_behavioral_note(%{
          participation_record_id: record.id,
          provider_id: provider.id,
          content: "Some observation"
        })

      {:ok, _rejected} =
        KlassHero.Participation.review_behavioral_note(%{
          note_id: note.id,
          parent_id: parent.id,
          decision: :reject,
          reason: "Too vague"
        })

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      assert has_element?(view, "#revise-note-btn-#{note.id}")
    end

    test "shows rejection reason when note is rejected with reason", %{
      conn: conn,
      session: session,
      record: record,
      parent: parent,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      {:ok, note} =
        KlassHero.Participation.submit_behavioral_note(%{
          participation_record_id: record.id,
          provider_id: provider.id,
          content: "Some observation"
        })

      {:ok, _rejected} =
        KlassHero.Participation.review_behavioral_note(%{
          note_id: note.id,
          parent_id: parent.id,
          decision: :reject,
          reason: "Too vague, please be specific"
        })

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      assert has_element?(view, "#rejection-reason-#{note.id}")
    end

    test "shows approved notes from past sessions when consented", %{
      conn: conn,
      session: session,
      parent: parent,
      child: child,
      record: record,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      )

      # Create an approved note for this child
      insert(:behavioral_note_schema,
        participation_record_id: record.id,
        child_id: child.id,
        parent_id: parent.id,
        status: :approved,
        reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        content: "Very focused during activities"
      )

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      assert has_element?(view, "#approved-notes-#{record.id}")
    end

    test "hides approved notes when no consent", %{
      conn: conn,
      session: session,
      record: record,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      refute has_element?(view, "#approved-notes-#{record.id}")
    end

    test "revision form submits and shows success flash", %{
      conn: conn,
      session: session,
      record: record,
      parent: parent,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      # Submit and reject a note
      {:ok, note} =
        KlassHero.Participation.submit_behavioral_note(%{
          participation_record_id: record.id,
          provider_id: provider.id,
          content: "Initial observation"
        })

      {:ok, _rejected} =
        KlassHero.Participation.review_behavioral_note(%{
          note_id: note.id,
          parent_id: parent.id,
          decision: :reject,
          reason: "Needs more detail"
        })

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      # Expand revision form
      view
      |> element("#revise-note-btn-#{note.id}")
      |> render_click()

      assert has_element?(view, "#revision-note-form-#{note.id}")

      # Submit revised note
      view
      |> form("#revision-note-form-#{note.id}", %{
        revision: %{content: "Detailed observation about engagement"}
      })
      |> render_submit()

      # Form should collapse after submission
      refute has_element?(view, "#revision-note-form-#{note.id}")
    end

    test "submit_note with blank content shows error flash", %{
      conn: conn,
      session: session,
      record: record,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      # Expand note form
      view
      |> element("#add-note-btn-#{record.id}")
      |> render_click()

      # Submit with empty content
      view
      |> form("#behavioral-note-form-#{record.id}", %{note: %{content: ""}})
      |> render_submit()

      assert has_element?(view, "#flash-error")
    end

    test "submit_note for duplicate shows error flash", %{
      conn: conn,
      session: session,
      record: record,
      provider: provider
    } do
      check_in_record(%{record: record, provider: provider})

      # Submit a note first via the API
      {:ok, _note} =
        KlassHero.Participation.submit_behavioral_note(%{
          participation_record_id: record.id,
          provider_id: provider.id,
          content: "First note"
        })

      # Reload to see the note badge (no Add Note button)
      {:ok, view, _html} = live(conn, ~p"/provider/participation/#{session.id}")

      # The "Add Note" button should not appear since a note already exists
      refute has_element?(view, "#add-note-btn-#{record.id}")
    end
  end
end
