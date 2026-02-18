defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.ParticipantPolicyRepository do
  @moduledoc """
  Ecto-based implementation of the ForManagingParticipantPolicies port.

  Handles storing and retrieving participant eligibility restrictions (age,
  gender, grade) for programs. Uses upsert semantics so a program's policy
  can be created or updated in a single call.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForManagingParticipantPolicies

  import Ecto.Query

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.ParticipantPolicyMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.ParticipantPolicySchema
  alias KlassHero.Repo

  require Logger

  @impl true
  def upsert(attrs) do
    schema_attrs = ParticipantPolicyMapper.to_schema_attrs(attrs)

    %ParticipantPolicySchema{}
    |> ParticipantPolicySchema.changeset(schema_attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :eligibility_at,
           :min_age_months,
           :max_age_months,
           :allowed_genders,
           :min_grade,
           :max_grade,
           :updated_at
         ]},
      conflict_target: :program_id,
      returning: true
    )
    |> case do
      {:ok, schema} ->
        Logger.info("[Enrollment.ParticipantPolicyRepository] Upserted participant policy",
          program_id: schema.program_id
        )

        {:ok, ParticipantPolicyMapper.to_domain(schema)}

      {:error, changeset} ->
        Logger.warning(
          "[Enrollment.ParticipantPolicyRepository] Failed to upsert participant policy",
          errors: inspect(changeset.errors)
        )

        {:error, changeset}
    end
  end

  @impl true
  def get_by_program_id(program_id) do
    case Repo.get_by(ParticipantPolicySchema, program_id: program_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, ParticipantPolicyMapper.to_domain(schema)}
    end
  end

  @impl true
  def get_policies_by_program_ids([]), do: %{}

  def get_policies_by_program_ids(program_ids) when is_list(program_ids) do
    from(p in ParticipantPolicySchema,
      where: p.program_id in ^program_ids
    )
    |> Repo.all()
    |> Map.new(fn schema ->
      {to_string(schema.program_id), ParticipantPolicyMapper.to_domain(schema)}
    end)
  end
end
