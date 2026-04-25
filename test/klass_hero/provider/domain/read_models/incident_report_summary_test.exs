defmodule KlassHero.Provider.Domain.ReadModels.IncidentReportSummaryTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.ReadModels.IncidentReportSummary

  describe "struct" do
    test "exposes the fields needed for the program incidents listing" do
      summary = %IncidentReportSummary{
        id: "report-1",
        provider_id: "prov-1",
        program_id: "prog-1",
        session_id: nil,
        category: :safety_concern,
        severity: :high,
        description: "A child slipped near the play area but is unharmed.",
        occurred_at: ~U[2026-04-20 14:30:00Z],
        reporter_display_name: "Jane Doe"
      }

      assert summary.id == "report-1"
      assert summary.reporter_display_name == "Jane Doe"
      assert summary.category == :safety_concern
      assert summary.severity == :high
    end

    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(IncidentReportSummary, %{id: "x"})
      end
    end
  end
end
