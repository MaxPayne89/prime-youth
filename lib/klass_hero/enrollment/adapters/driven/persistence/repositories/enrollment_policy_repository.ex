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
  def get_remaining_capacities([]), do: %{}

  def get_remaining_capacities(program_ids) when is_list(program_ids) do
    # Trigger: batch query for remaining capacity across multiple programs
    # Why: avoids N+1 queries when listing programs with capacity info
    # Outcome: single query returns all capacity data as a map

    # Step 1: fetch policies for all requested programs
    policies =
      from(p in EnrollmentPolicySchema,
        where: p.program_id in ^program_ids,
        select: {p.program_id, p.max_enrollment}
      )
      |> Repo.all()
      |> Map.new()

    # Step 2: fetch active enrollment counts for programs that have a max
    capped_ids = for {id, max} when not is_nil(max) <- policies, do: id

    active_counts =
      if capped_ids == [] do
        %{}
      else
        from(e in EnrollmentSchema,
          where: e.program_id in ^capped_ids and e.status in ^@active_statuses,
          group_by: e.program_id,
          select: {e.program_id, count(e.id)}
        )
        |> Repo.all()
        |> Map.new()
      end

    # Step 3: build result map
    Map.new(program_ids, fn id ->
      case Map.get(policies, id) do
        nil -> {id, :unlimited}
        max -> {id, max(max - Map.get(active_counts, id, 0), 0)}
      end
    end)
  end

  @impl true
  def count_active_enrollments(program_id) do
    from(e in EnrollmentSchema,
      where: e.program_id == ^program_id and e.status in ^@active_statuses,
      select: count(e.id)
    )
    |> Repo.one()
  end

  @impl true
  def count_active_enrollments_batch([]), do: %{}

  def count_active_enrollments_batch(program_ids) when is_list(program_ids) do
    from(e in EnrollmentSchema,
      where: e.program_id in ^program_ids and e.status in ^@active_statuses,
      group_by: e.program_id,
      select: {e.program_id, count(e.id)}
    )
    |> Repo.all()
    |> Map.new()
    |> then(fn counts ->
      # Ensure all requested IDs appear in result (0 for missing)
      Map.new(program_ids, fn id -> {id, Map.get(counts, id, 0)} end)
    end)
  end
end
