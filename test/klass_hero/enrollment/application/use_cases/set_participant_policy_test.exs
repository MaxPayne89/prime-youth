defmodule KlassHero.Enrollment.Application.UseCases.SetParticipantPolicyTest do
  @moduledoc """
  Tests for SetParticipantPolicy use case.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.ParticipantPolicyRepository
  alias KlassHero.Enrollment.Application.UseCases.SetParticipantPolicy
  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy

  describe "execute/1" do
    test "creates a new participant policy and returns ok" do
      program = insert(:program_schema)

      attrs = %{
        program_id: program.id,
        min_age_months: 72,
        max_age_months: 144
      }

      assert {:ok, %ParticipantPolicy{} = policy} = SetParticipantPolicy.execute(attrs)
      assert policy.program_id == to_string(program.id)
      assert policy.min_age_months == 72
      assert policy.max_age_months == 144
    end

    test "updates an existing participant policy via upsert" do
      program = insert(:program_schema)

      {:ok, _} =
        ParticipantPolicyRepository.upsert(%{
          program_id: program.id,
          min_age_months: 48
        })

      attrs = %{
        program_id: program.id,
        min_age_months: 96,
        max_age_months: 168
      }

      assert {:ok, %ParticipantPolicy{} = policy} = SetParticipantPolicy.execute(attrs)
      assert policy.program_id == to_string(program.id)
      assert policy.min_age_months == 96
      assert policy.max_age_months == 168
    end

    test "returns error on missing program_id" do
      assert {:error, _changeset} = SetParticipantPolicy.execute(%{min_age_months: 48})
    end
  end
end
