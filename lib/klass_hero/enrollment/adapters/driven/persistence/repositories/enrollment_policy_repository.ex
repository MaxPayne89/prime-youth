defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepository do
  @moduledoc """
  Ecto-based implementation of the ForManagingEnrollmentPolicies port.

  Handles storing and retrieving enrollment capacity configuration (min/max
  enrollment) for programs. Uses upsert semantics so a program's policy can
  be created or updated in a single call.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForManagingEnrollmentPolicies

  import Ecto.Query

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Repo

  require Logger

  @active_statuses ~w(pending confirmed)

  @impl true
  def upsert(attrs) do
    schema_attrs = EnrollmentPolicyMapper.to_schema_attrs(attrs)

    %EnrollmentPolicySchema{}
    |> EnrollmentPolicySchema.changeset(schema_attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:min_enrollment, :max_enrollment, :updated_at]},
      conflict_target: :program_id,
      returning: true
    )
    |> case do
      {:ok, schema} ->
        Logger.info("[Enrollment.PolicyRepository] Upserted enrollment policy",
          program_id: schema.program_id,
          min: schema.min_enrollment,
          max: schema.max_enrollment
        )

        {:ok, EnrollmentPolicyMapper.to_domain(schema)}

      {:error, changeset} ->
        Logger.warning("[Enrollment.PolicyRepository] Failed to upsert policy",
          errors: inspect(changeset.errors)
        )

        {:error, changeset}
    end
  end

  @impl true
  def get_by_program_id(program_id) do
    case Repo.get_by(EnrollmentPolicySchema, program_id: program_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, EnrollmentPolicyMapper.to_domain(schema)}
    end
  end

  @impl true
  def get_remaining_capacity(program_id) do
    case Repo.get_by(EnrollmentPolicySchema, program_id: program_id) do
      # Trigger: no policy row exists for this program
      # Why: programs without a policy have no enrollment cap
      # Outcome: unlimited capacity returned
      nil ->
        {:ok, :unlimited}

      # Trigger: policy exists but max_enrollment is not set
      # Why: only min_enrollment was configured (viability threshold only)
      # Outcome: unlimited capacity returned
      %{max_enrollment: nil} ->
        {:ok, :unlimited}

      # Trigger: policy has a max_enrollment value
      # Why: hard cap on enrollment — remaining = max - active count
      # Outcome: non-negative remaining capacity (floored at 0)
      %{max_enrollment: max} ->
        active_count = count_active_enrollments(program_id)
        {:ok, max(max - active_count, 0)}
    end
  end

  @impl true
  def count_active_enrollments(program_id) do
    from(e in EnrollmentSchema,
      where: e.program_id == ^program_id and e.status in ^@active_statuses,
      select: count(e.id)
    )
    |> Repo.one()
  end
end
