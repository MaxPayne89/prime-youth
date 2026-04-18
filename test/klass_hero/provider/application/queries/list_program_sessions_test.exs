defmodule KlassHero.Provider.Application.Queries.ListProgramSessionsTest do
  @moduledoc """
  Integration tests for the ListProgramSessions use case.

  Tests the complete data flow: Use Case -> Read Repository -> Database -> SessionDetail read model.
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Application.Queries.ListProgramSessions
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail
  alias KlassHero.Repo

  describe "run/2" do
    test "returns sessions for the provider's program ordered by date and start time" do
      provider_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      insert_row(%{
        session_id: Ecto.UUID.generate(),
        program_id: program_id,
        program_title: "Judo",
        provider_id: provider_id,
        session_date: ~D[2026-05-02],
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        status: :scheduled
      })

      insert_row(%{
        session_id: Ecto.UUID.generate(),
        program_id: program_id,
        program_title: "Judo",
        provider_id: provider_id,
        session_date: ~D[2026-05-01],
        start_time: ~T[15:00:00],
        end_time: ~T[16:00:00],
        status: :scheduled
      })

      [first, second] = ListProgramSessions.run(provider_id, program_id)

      assert %SessionDetail{session_date: ~D[2026-05-01]} = first
      assert %SessionDetail{session_date: ~D[2026-05-02]} = second
    end

    test "returns [] when the program has no sessions" do
      assert [] == ListProgramSessions.run(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "does not leak sessions across providers" do
      program_id = Ecto.UUID.generate()
      mine = Ecto.UUID.generate()
      theirs = Ecto.UUID.generate()

      insert_row(%{
        session_id: Ecto.UUID.generate(),
        program_id: program_id,
        program_title: "Judo",
        provider_id: theirs,
        session_date: ~D[2026-05-01],
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        status: :scheduled
      })

      assert [] == ListProgramSessions.run(mine, program_id)
    end
  end

  defp insert_row(attrs) do
    %ProviderSessionDetailSchema{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!()
  end
end
