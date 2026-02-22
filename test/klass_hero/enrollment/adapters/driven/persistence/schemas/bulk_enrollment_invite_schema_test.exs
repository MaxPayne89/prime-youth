defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema

  @valid_attrs %{
    program_id: Ecto.UUID.generate(),
    provider_id: Ecto.UUID.generate(),
    child_first_name: "Avyan",
    child_last_name: "Srivastava",
    child_date_of_birth: ~D[2016-01-01],
    guardian_email: "parent@example.com",
    guardian_first_name: "Vaibhav",
    guardian_last_name: "Srivastava",
    status: "pending"
  }

  describe "changeset/2" do
    test "valid with required fields" do
      changeset =
        BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, @valid_attrs)

      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(%{})
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).program_id
      assert errors_on(changeset).provider_id
      assert errors_on(changeset).child_first_name
      assert errors_on(changeset).child_last_name
      assert errors_on(changeset).child_date_of_birth
      assert errors_on(changeset).guardian_email
    end

    test "validates status inclusion" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(Map.put(@valid_attrs, :status, "invalid"))
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).status
    end

    test "validates guardian_email format" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(
          Map.put(@valid_attrs, :guardian_email, "not-an-email")
        )
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).guardian_email
    end

    test "accepts optional second guardian fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          guardian2_email: "parent2@example.com",
          guardian2_first_name: "Alex",
          guardian2_last_name: "Srivastava"
        })

      changeset = BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, attrs)
      assert changeset.valid?
    end

    test "accepts optional medical and consent fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          school_grade: 3,
          school_name: "Berlin International School",
          medical_conditions: "Asthma",
          nut_allergy: true,
          consent_photo_marketing: true,
          consent_photo_social_media: false
        })

      changeset = BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, attrs)
      assert changeset.valid?
    end

    test "rejects future child_date_of_birth" do
      future_date = Date.add(Date.utc_today(), 30)

      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(
          Map.put(@valid_attrs, :child_date_of_birth, future_date)
        )
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert "must be in the past" in errors_on(changeset).child_date_of_birth
    end

    test "validates school_grade range" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(Map.put(@valid_attrs, :school_grade, 14))
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).school_grade
    end

    test "defaults status to pending" do
      attrs = Map.delete(@valid_attrs, :status)
      changeset = BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end
  end

  describe "import_changeset/2" do
    test "valid with CSV import fields" do
      changeset =
        BulkEnrollmentInviteSchema.import_changeset(%BulkEnrollmentInviteSchema{}, @valid_attrs)

      assert changeset.valid?
    end

    test "does not accept lifecycle fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          invite_token: "some-token",
          invite_sent_at: ~U[2026-01-01 00:00:00Z],
          enrollment_id: Ecto.UUID.generate(),
          error_details: "should be ignored"
        })

      changeset =
        BulkEnrollmentInviteSchema.import_changeset(%BulkEnrollmentInviteSchema{}, attrs)

      assert changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :invite_token)
      refute Ecto.Changeset.get_change(changeset, :invite_sent_at)
      refute Ecto.Changeset.get_change(changeset, :enrollment_id)
      refute Ecto.Changeset.get_change(changeset, :error_details)
    end

    test "does not accept status field" do
      attrs = Map.put(@valid_attrs, :status, "invite_sent")

      changeset =
        BulkEnrollmentInviteSchema.import_changeset(%BulkEnrollmentInviteSchema{}, attrs)

      refute Ecto.Changeset.get_change(changeset, :status)
    end

    test "requires mandatory fields" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.import_changeset(%{})
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).program_id
      assert errors_on(changeset).guardian_email
    end
  end

  describe "transition_changeset/2" do
    test "allows valid transition from pending to invite_sent" do
      invite = %BulkEnrollmentInviteSchema{status: "pending"}

      changeset =
        BulkEnrollmentInviteSchema.transition_changeset(invite, %{
          status: "invite_sent",
          invite_token: "abc123",
          invite_sent_at: ~U[2026-01-15 10:00:00Z]
        })

      assert changeset.valid?
    end

    test "allows valid transition from invite_sent to registered" do
      invite = %BulkEnrollmentInviteSchema{status: "invite_sent"}

      changeset =
        BulkEnrollmentInviteSchema.transition_changeset(invite, %{
          status: "registered",
          registered_at: ~U[2026-01-20 10:00:00Z]
        })

      assert changeset.valid?
    end

    test "allows valid transition from registered to enrolled" do
      invite = %BulkEnrollmentInviteSchema{status: "registered"}
      enrollment_id = Ecto.UUID.generate()

      changeset =
        BulkEnrollmentInviteSchema.transition_changeset(invite, %{
          status: "enrolled",
          enrolled_at: ~U[2026-01-25 10:00:00Z],
          enrollment_id: enrollment_id
        })

      assert changeset.valid?
    end

    test "allows transition to failed from any active status" do
      for status <- ["pending", "invite_sent", "registered"] do
        invite = %BulkEnrollmentInviteSchema{status: status}

        changeset =
          BulkEnrollmentInviteSchema.transition_changeset(invite, %{
            status: "failed",
            error_details: "Something went wrong"
          })

        assert changeset.valid?, "Expected transition from #{status} to failed to be valid"
      end
    end

    test "allows retry from failed back to pending" do
      invite = %BulkEnrollmentInviteSchema{status: "failed"}

      changeset =
        BulkEnrollmentInviteSchema.transition_changeset(invite, %{status: "pending"})

      assert changeset.valid?
    end

    test "rejects invalid transition from pending to enrolled" do
      invite = %BulkEnrollmentInviteSchema{status: "pending"}

      changeset =
        invite
        |> BulkEnrollmentInviteSchema.transition_changeset(%{status: "enrolled"})
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert "cannot transition from pending to enrolled" in errors_on(changeset).status
    end

    test "rejects transition from enrolled (terminal state)" do
      invite = %BulkEnrollmentInviteSchema{status: "enrolled"}

      changeset =
        invite
        |> BulkEnrollmentInviteSchema.transition_changeset(%{status: "pending"})
        |> Map.put(:action, :validate)

      refute changeset.valid?
    end
  end
end
