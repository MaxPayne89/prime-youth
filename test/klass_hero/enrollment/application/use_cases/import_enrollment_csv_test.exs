defmodule KlassHero.Enrollment.Application.UseCases.ImportEnrollmentCsvTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Enrollment.Application.UseCases.ImportEnrollmentCsv
  alias KlassHero.Repo

  # -- setup helpers ---------------------------------------------------------

  defp setup_provider_with_programs(_context) do
    provider = insert(:provider_profile_schema)
    program1 = insert(:program_schema, provider_id: provider.id, title: "Ballsports & Parkour")
    program2 = insert(:program_schema, provider_id: provider.id, title: "Organic Arts")
    %{provider: provider, program1: program1, program2: program2}
  end

  # -- CSV builder -----------------------------------------------------------

  defp build_csv(rows) do
    headers =
      [
        "Participant information: First name",
        "Participant information: Last name",
        "Participant information: Date of birth",
        "Parent/guardian information: First name",
        "Parent/guardian information: Last name",
        "Parent/guardian information: Email address",
        "Parent/guardian 2 information: First name",
        "Parent/guardian 2 information: Last name",
        "Parent/guardian 2 information: Email address",
        "School information: Grade",
        "School information: Name",
        "Medical/allergy information: Do you have medical conditions and special needs?",
        "Medical/allergy information: Medical conditions and special needs",
        "Medical/allergy information: Nut allergy",
        ~s|Photography/video release permission: I agree that photos showing my child at camp may appear in marketing materials (e.g. posters, website) free of charge. this agreement is valid for unlimited time for all types of existing media and those that may be created.|,
        ~s|Photography/video release permission: I agree that photos and films showing my child participating in activities may appear for marketing purposes on prime youth's social media channels (e.g. facebook, instagram, youtube) free of charge, valid for unlimited time and without revealing my children's identity.|,
        "Program",
        "Instructor",
        "Season"
      ]
      |> Enum.map_join(",", &csv_escape/1)

    data_rows =
      Enum.map(rows, fn row ->
        [
          row[:first] || "Alice",
          row[:last] || "Smith",
          row[:dob] || "1/1/2016",
          row[:parent_first] || "Bob",
          row[:parent_last] || "Smith",
          row[:email] || "parent@example.com",
          row[:parent2_first] || "",
          row[:parent2_last] || "",
          row[:parent2_email] || "",
          row[:grade] || "",
          row[:school] || "",
          row[:has_medical] || "",
          row[:medical] || "",
          row[:nut_allergy] || "",
          row[:photo_marketing] || "",
          row[:photo_social] || "",
          row[:program] || "Ballsports & Parkour",
          row[:instructor] || "",
          row[:season] || "Test Season"
        ]
        |> Enum.map_join(",", &csv_escape/1)
      end)

    [headers | data_rows] |> Enum.join("\n")
  end

  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  # -- happy path ------------------------------------------------------------

  describe "execute/2 happy path" do
    setup :setup_provider_with_programs

    test "imports valid CSV with 2 rows across 2 programs", %{provider: provider} do
      csv =
        build_csv([
          %{
            first: "Alice",
            last: "Smith",
            email: "alice@test.com",
            program: "Ballsports & Parkour"
          },
          %{first: "Bob", last: "Jones", email: "bob@test.com", program: "Organic Arts"}
        ])

      assert {:ok, %{created: 2}} = ImportEnrollmentCsv.execute(provider.id, csv)

      assert Repo.aggregate(BulkEnrollmentInviteSchema, :count) == 2
    end

    test "persists correct data for each row", %{
      provider: provider,
      program1: program1,
      program2: program2
    } do
      csv =
        build_csv([
          %{
            first: "Alice",
            last: "Smith",
            dob: "3/15/2017",
            email: "alice@test.com",
            parent_first: "Carol",
            parent_last: "Smith",
            program: "Ballsports & Parkour",
            grade: "2",
            school: "BIS"
          },
          %{
            first: "Bob",
            last: "Jones",
            dob: "12/1/2016",
            email: "bob@test.com",
            parent_first: "David",
            parent_last: "Jones",
            program: "Organic Arts",
            nut_allergy: "Yes",
            photo_marketing: "Yes"
          }
        ])

      assert {:ok, %{created: 2}} = ImportEnrollmentCsv.execute(provider.id, csv)

      invites = Repo.all(BulkEnrollmentInviteSchema)
      alice_invite = Enum.find(invites, &(&1.child_first_name == "Alice"))
      bob_invite = Enum.find(invites, &(&1.child_first_name == "Bob"))

      assert alice_invite.program_id == program1.id
      assert alice_invite.provider_id == provider.id
      assert alice_invite.child_date_of_birth == ~D[2017-03-15]
      assert alice_invite.guardian_email == "alice@test.com"
      assert alice_invite.school_grade == 2
      assert alice_invite.school_name == "BIS"
      assert alice_invite.status == "pending"

      assert bob_invite.program_id == program2.id
      assert bob_invite.nut_allergy == true
      assert bob_invite.consent_photo_marketing == true
    end
  end

  # -- parse errors ----------------------------------------------------------

  describe "execute/2 parse errors" do
    setup :setup_provider_with_programs

    test "returns parse error for empty CSV", %{provider: provider} do
      assert {:error, %{parse_errors: [{0, msg}]}} = ImportEnrollmentCsv.execute(provider.id, "")
      assert msg =~ "empty"
    end

    test "returns parse error for invalid headers", %{provider: provider} do
      csv = "Wrong,Headers\nval1,val2\n"

      assert {:error, %{parse_errors: [{0, msg}]}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      assert msg =~ "Missing required columns"
    end
  end

  # -- validation errors -----------------------------------------------------

  describe "execute/2 validation errors" do
    setup :setup_provider_with_programs

    test "returns validation errors for missing guardian_email", %{provider: provider} do
      csv = build_csv([%{email: ""}])

      assert {:error, %{validation_errors: errors}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      assert [{1, field_errors}] = errors
      assert Enum.any?(field_errors, fn {field, _msg} -> field == :guardian_email end)
    end

    test "returns validation error for unknown program", %{provider: provider} do
      csv = build_csv([%{email: "test@test.com", program: "Nonexistent Program"}])

      assert {:error, %{validation_errors: errors}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      assert [{1, field_errors}] = errors
      assert Enum.any?(field_errors, fn {field, _msg} -> field == :program_name end)
    end

    test "accumulates errors from multiple rows", %{provider: provider} do
      csv =
        build_csv([
          %{email: "", program: "Ballsports & Parkour"},
          %{email: "valid@test.com", program: "Unknown Program"}
        ])

      assert {:error, %{validation_errors: errors}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      assert length(errors) == 2
    end
  end

  # -- batch duplicate detection ---------------------------------------------

  describe "execute/2 batch duplicates" do
    setup :setup_provider_with_programs

    test "detects duplicate rows within the same CSV", %{provider: provider} do
      csv =
        build_csv([
          %{
            first: "Alice",
            last: "Smith",
            email: "parent@test.com",
            program: "Ballsports & Parkour"
          },
          %{
            first: "Alice",
            last: "Smith",
            email: "parent@test.com",
            program: "Ballsports & Parkour"
          }
        ])

      assert {:error, %{duplicate_errors: dupes}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      # Trigger: second row is the duplicate
      # Why: first occurrence is kept; subsequent ones flagged
      # Outcome: row 2 has the error
      assert [{2, msg}] = dupes
      assert msg =~ "Duplicate entry in CSV"
    end

    test "same child in different programs is not a duplicate", %{provider: provider} do
      csv =
        build_csv([
          %{
            first: "Alice",
            last: "Smith",
            email: "parent@test.com",
            program: "Ballsports & Parkour"
          },
          %{first: "Alice", last: "Smith", email: "parent@test.com", program: "Organic Arts"}
        ])

      assert {:ok, %{created: 2}} = ImportEnrollmentCsv.execute(provider.id, csv)
    end
  end

  # -- existing duplicate detection ------------------------------------------

  describe "execute/2 existing duplicates" do
    setup :setup_provider_with_programs

    test "detects invites that already exist in the database", %{
      provider: provider,
      program1: program1
    } do
      # Pre-insert an invite
      existing_attrs = %{
        program_id: program1.id,
        provider_id: provider.id,
        child_first_name: "Alice",
        child_last_name: "Smith",
        child_date_of_birth: ~D[2016-01-01],
        guardian_email: "parent@test.com"
      }

      repo_module =
        Application.fetch_env!(:klass_hero, :enrollment)
        |> Keyword.fetch!(:for_storing_bulk_enrollment_invites)

      {:ok, 1} = repo_module.create_batch([existing_attrs])

      # Now try to import the same child+program combo
      csv =
        build_csv([
          %{
            first: "Alice",
            last: "Smith",
            email: "parent@test.com",
            program: "Ballsports & Parkour"
          }
        ])

      assert {:error, %{duplicate_errors: dupes}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      assert [{1, msg}] = dupes
      assert msg =~ "already exists"
    end
  end

  # -- all-or-nothing --------------------------------------------------------

  describe "execute/2 all-or-nothing" do
    setup :setup_provider_with_programs

    test "nothing is persisted when one row has validation errors", %{provider: provider} do
      csv =
        build_csv([
          %{
            first: "Alice",
            last: "Smith",
            email: "valid@test.com",
            program: "Ballsports & Parkour"
          },
          %{first: "Bob", last: "Jones", email: "", program: "Ballsports & Parkour"}
        ])

      assert {:error, %{validation_errors: _}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      assert Repo.aggregate(BulkEnrollmentInviteSchema, :count) == 0
    end

    test "nothing is persisted when batch duplicate detected", %{provider: provider} do
      csv =
        build_csv([
          %{
            first: "Alice",
            last: "Smith",
            email: "parent@test.com",
            program: "Ballsports & Parkour"
          },
          %{
            first: "Alice",
            last: "Smith",
            email: "parent@test.com",
            program: "Ballsports & Parkour"
          }
        ])

      assert {:error, %{duplicate_errors: _}} =
               ImportEnrollmentCsv.execute(provider.id, csv)

      assert Repo.aggregate(BulkEnrollmentInviteSchema, :count) == 0
    end
  end

  # -- real CSV file ---------------------------------------------------------

  describe "execute/2 with real CSV file" do
    setup :setup_provider_with_programs

    test "imports the project template CSV successfully", %{provider: provider} do
      csv = File.read!(Path.join(File.cwd!(), "program.import.template.Klass.Hero.csv"))

      assert {:ok, %{created: count}} = ImportEnrollmentCsv.execute(provider.id, csv)

      # The real CSV has 20 data rows
      assert count == 20
      assert Repo.aggregate(BulkEnrollmentInviteSchema, :count) == 20
    end
  end
end
