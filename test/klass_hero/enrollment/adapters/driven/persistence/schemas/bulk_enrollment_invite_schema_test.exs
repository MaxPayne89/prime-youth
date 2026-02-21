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
end
