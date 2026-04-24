defmodule KlassHero.Provider.Domain.Models.IncidentReportTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Models.IncidentReport

  @valid_program_attrs %{
    id: Ecto.UUID.generate(),
    provider_profile_id: Ecto.UUID.generate(),
    reporter_user_id: Ecto.UUID.generate(),
    program_id: Ecto.UUID.generate(),
    category: :safety_concern,
    severity: :high,
    description: "A child tripped on the stairs during drop-off today.",
    occurred_at: ~U[2026-04-22 14:00:00Z]
  }

  @valid_session_attrs Map.merge(@valid_program_attrs, %{
                         program_id: nil,
                         session_id: Ecto.UUID.generate()
                       })

  describe "new/1" do
    test "builds a valid program-scoped incident" do
      assert {:ok, %IncidentReport{} = report} = IncidentReport.new(@valid_program_attrs)
      assert report.program_id == @valid_program_attrs.program_id
      assert is_nil(report.session_id)
    end

    test "builds a valid session-scoped incident" do
      assert {:ok, %IncidentReport{} = report} = IncidentReport.new(@valid_session_attrs)
      assert report.session_id == @valid_session_attrs.session_id
      assert is_nil(report.program_id)
    end

    test "rejects when both program_id and session_id are set" do
      attrs = Map.put(@valid_program_attrs, :session_id, Ecto.UUID.generate())
      assert {:error, errors} = IncidentReport.new(attrs)
      assert errors[:target] == "exactly one of program_id or session_id must be set"
    end

    test "rejects when neither program_id nor session_id is set" do
      attrs = Map.merge(@valid_program_attrs, %{program_id: nil, session_id: nil})
      assert {:error, errors} = IncidentReport.new(attrs)
      assert errors[:target] == "exactly one of program_id or session_id must be set"
    end

    test "rejects invalid category" do
      attrs = Map.put(@valid_program_attrs, :category, :bogus)
      assert {:error, errors} = IncidentReport.new(attrs)
      assert errors[:category] == "is invalid"
    end

    test "rejects invalid severity" do
      attrs = Map.put(@valid_program_attrs, :severity, :nuclear)
      assert {:error, errors} = IncidentReport.new(attrs)
      assert errors[:severity] == "is invalid"
    end

    test "rejects too-short description" do
      attrs = Map.put(@valid_program_attrs, :description, "short")
      assert {:error, errors} = IncidentReport.new(attrs)
      assert errors[:description] =~ "at least 10"
    end

    test "rejects occurred_at in the future" do
      future = DateTime.add(DateTime.utc_now(), 86_400)
      attrs = Map.put(@valid_program_attrs, :occurred_at, future)
      assert {:error, errors} = IncidentReport.new(attrs)
      assert errors[:occurred_at] == "cannot be in the future"
    end

    test "rejects photo_url without original_filename" do
      attrs = Map.put(@valid_program_attrs, :photo_url, "some/key")
      assert {:error, errors} = IncidentReport.new(attrs)
      assert errors[:original_filename] == "is required when photo_url is set"
    end

    test "accepts photo_url with original_filename" do
      attrs =
        Map.merge(@valid_program_attrs, %{
          photo_url: "incident-reports/photo.jpg",
          original_filename: "photo.jpg"
        })

      assert {:ok, report} = IncidentReport.new(attrs)
      assert report.photo_url == "incident-reports/photo.jpg"
      assert report.original_filename == "photo.jpg"
    end

    test "accepts original_filename without photo_url (unpaired but harmless)" do
      attrs = Map.put(@valid_program_attrs, :original_filename, "photo.jpg")

      assert {:ok, report} = IncidentReport.new(attrs)
      assert is_nil(report.photo_url)
      assert report.original_filename == "photo.jpg"
    end

    test "ignores unknown attrs keys rather than raising" do
      attrs = Map.put(@valid_program_attrs, :bogus, "value")
      assert {:ok, _report} = IncidentReport.new(attrs)
    end

    test "valid_categories/0 exposes the full category atom list" do
      assert IncidentReport.valid_categories() ==
               [
                 :safety_concern,
                 :behavioral_issue,
                 :injury,
                 :property_damage,
                 :policy_violation,
                 :other
               ]
    end

    test "valid_severities/0 exposes the full severity atom list" do
      assert IncidentReport.valid_severities() == [:low, :medium, :high, :critical]
    end
  end
end
