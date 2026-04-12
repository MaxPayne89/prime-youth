defmodule KlassHero.Participation.Application.Commands.SeedSessionRosterTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository
  alias KlassHero.Participation.Application.Commands.SeedSessionRoster

  describe "execute/2" do
    test "creates participation records for enrolled children" do
      enrollment = insert(:enrollment_schema, status: "confirmed")

      session =
        insert(:program_session_schema,
          program_id: enrollment.program_id,
          status: "scheduled"
        )

      assert :ok = SeedSessionRoster.execute(session.id, enrollment.program_id)

      records = ParticipationRepository.list_by_session(session.id)
      assert length(records) == 1
      assert hd(records).child_id == enrollment.child_id
      assert hd(records).status == :registered
    end

    test "is idempotent — running twice does not duplicate records" do
      enrollment = insert(:enrollment_schema, status: "confirmed")

      session =
        insert(:program_session_schema,
          program_id: enrollment.program_id,
          status: "scheduled"
        )

      assert :ok = SeedSessionRoster.execute(session.id, enrollment.program_id)
      assert :ok = SeedSessionRoster.execute(session.id, enrollment.program_id)

      records = ParticipationRepository.list_by_session(session.id)
      assert length(records) == 1
    end

    test "handles program with no enrollments gracefully" do
      session = insert(:program_session_schema, status: "scheduled")

      assert :ok = SeedSessionRoster.execute(session.id, session.program_id)

      records = ParticipationRepository.list_by_session(session.id)
      assert records == []
    end

    test "returns :ok when seeding fails (best-effort)" do
      enrollment = insert(:enrollment_schema, status: "confirmed")
      non_existent_session_id = Ecto.UUID.generate()

      assert :ok = SeedSessionRoster.execute(non_existent_session_id, enrollment.program_id)
    end
  end
end
