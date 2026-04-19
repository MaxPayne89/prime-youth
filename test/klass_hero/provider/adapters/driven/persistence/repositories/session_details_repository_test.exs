defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionDetailsRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionDetailsRepository
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail
  alias KlassHero.Repo

  defp insert_row(attrs) do
    %ProviderSessionDetailSchema{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!()
  end

  describe "list_by_program/2" do
    test "returns rows ordered by session_date then start_time" do
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

      [first, second] = SessionDetailsRepository.list_by_program(provider_id, program_id)

      assert %SessionDetail{session_date: ~D[2026-05-01]} = first
      assert %SessionDetail{session_date: ~D[2026-05-02]} = second
    end

    test "returns [] for unknown program" do
      assert [] == SessionDetailsRepository.list_by_program(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "does not leak across providers" do
      program_id = Ecto.UUID.generate()
      mine = Ecto.UUID.generate()
      theirs = Ecto.UUID.generate()

      insert_row(%{
        session_id: Ecto.UUID.generate(),
        program_id: program_id,
        program_title: "J",
        provider_id: theirs,
        session_date: ~D[2026-05-01],
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        status: :scheduled
      })

      assert [] == SessionDetailsRepository.list_by_program(mine, program_id)
    end
  end
end
