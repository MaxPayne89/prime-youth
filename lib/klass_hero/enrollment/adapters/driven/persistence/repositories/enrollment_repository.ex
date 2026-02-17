defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository do
  @moduledoc """
  Repository implementation for managing enrollments in the database.

  Implements the ForManagingEnrollments port with:
  - Domain entity mapping via EnrollmentMapper
  - Composable queries via EnrollmentQueries
  - Idiomatic "let it crash" error handling

  Data integrity is enforced at the database level through:
  - NOT NULL constraints on required fields
  - UNIQUE partial index on (program_id, child_id) for active enrollments
  - Foreign key constraints to programs, children, and parents tables

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForManagingEnrollments

  import Ecto.Query

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Queries.EnrollmentQueries
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.EctoErrorHelpers

  require Logger

  @active_statuses ~w(pending confirmed)

  @impl true
  @doc """
  Creates a new enrollment in the database.

  Returns:
  - `{:ok, Enrollment.t()}` on success
  - `{:error, :duplicate_resource}` - Active enrollment already exists for this child/program
  - `{:error, changeset}` - Validation failure
  """
  def create(attrs) when is_map(attrs) do
    %EnrollmentSchema{}
    |> EnrollmentSchema.create_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        Logger.info("[Enrollment.Repository] Created enrollment",
          enrollment_id: schema.id,
          program_id: attrs[:program_id],
          child_id: attrs[:child_id],
          parent_id: attrs[:parent_id]
        )

        {:ok, EnrollmentMapper.to_domain(schema)}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if EctoErrorHelpers.unique_constraint_violation?(errors, :program_id) do
          Logger.warning("[Enrollment.Repository] Duplicate active enrollment",
            program_id: attrs[:program_id],
            child_id: attrs[:child_id]
          )

          {:error, :duplicate_resource}
        else
          Logger.warning("[Enrollment.Repository] Validation error creating enrollment",
            program_id: attrs[:program_id],
            child_id: attrs[:child_id],
            errors: inspect(changeset.errors)
          )

          {:error, changeset}
        end
    end
  end

  @impl true
  @doc """
  Creates an enrollment with atomic capacity check.

  Uses Ecto.Multi to lock the enrollment policy row (SELECT FOR UPDATE),
  verify remaining capacity, and create the enrollment in a single transaction.
  Prevents TOCTOU race conditions where concurrent requests could both pass
  the capacity check and exceed max enrollment.
  """
  # Trigger: program_id is nil (missing required field)
  # Why: let downstream changeset validation handle missing fields
  # Outcome: skip capacity check, changeset will reject the enrollment
  def create_with_capacity_check(attrs, nil), do: create(attrs)

  def create_with_capacity_check(attrs, program_id)
      when is_map(attrs) and is_binary(program_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:lock_and_check, fn repo, _changes ->
      # Trigger: lock the policy row to prevent concurrent capacity checks
      # Why: SELECT FOR UPDATE serializes concurrent enrollment attempts
      # Outcome: only one request proceeds at a time per program
      query =
        from(p in EnrollmentPolicySchema,
          where: p.program_id == ^program_id,
          lock: "FOR UPDATE"
        )

      case repo.one(query) do
        nil ->
          {:ok, :unlimited}

        # Trigger: policy row exists — use domain model to check capacity
        # Why: avoids duplicating EnrollmentPolicy.has_capacity?/2 logic inline
        # Outcome: single source of truth for capacity rules
        %EnrollmentPolicySchema{} = schema ->
          policy = EnrollmentPolicyMapper.to_domain(schema)
          active = count_active_enrollments_in_tx(repo, program_id)

          if EnrollmentPolicy.has_capacity?(policy, active) do
            remaining =
              if policy.max_enrollment,
                do: policy.max_enrollment - active,
                else: :unlimited

            {:ok, remaining}
          else
            {:error, :program_full}
          end
      end
    end)
    |> Ecto.Multi.run(:create, fn _repo, _changes ->
      create(attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create: enrollment}} -> {:ok, enrollment}
      {:error, :lock_and_check, :program_full, _} -> {:error, :program_full}
      {:error, :create, reason, _} -> {:error, reason}
    end
  end

  defp count_active_enrollments_in_tx(repo, program_id) do
    from(e in EnrollmentSchema,
      where: e.program_id == ^program_id and e.status in ^@active_statuses,
      select: count(e.id)
    )
    |> repo.one()
  end

  @impl true
  @doc """
  Retrieves an enrollment by ID from the database.

  Returns:
  - `{:ok, Enrollment.t()}` when enrollment is found
  - `{:error, :not_found}` when no enrollment exists with the given ID
  """
  def get_by_id(id) when is_binary(id) do
    case Repo.get(EnrollmentSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, EnrollmentMapper.to_domain(schema)}
    end
  end

  @impl true
  @doc """
  Lists all enrollments for a parent from the database.

  Returns list of Enrollment.t(), ordered by enrolled_at descending.
  Returns empty list if no enrollments found.
  """
  def list_by_parent(parent_id) when is_binary(parent_id) do
    EnrollmentQueries.base()
    |> EnrollmentQueries.by_parent(parent_id)
    |> EnrollmentQueries.order_by_enrolled_at_desc()
    |> Repo.all()
    |> EnrollmentMapper.to_domain_list()
  end

  @impl true
  @doc """
  Counts active enrollments for a parent within a date range.

  Only counts enrollments with status 'pending' or 'confirmed'.

  Returns non-negative integer count.
  """
  def count_monthly_bookings(parent_id, start_date, end_date) when is_binary(parent_id) do
    EnrollmentQueries.base()
    |> EnrollmentQueries.by_parent(parent_id)
    |> EnrollmentQueries.active_only()
    |> EnrollmentQueries.by_date_range(start_date, end_date)
    |> EnrollmentQueries.count()
    |> Repo.one()
  end

  @impl true
  def list_enrolled_identity_ids(program_id) when is_binary(program_id) do
    EnrollmentQueries.base()
    |> EnrollmentQueries.by_program(program_id)
    |> EnrollmentQueries.active_only()
    |> join(:inner, [e], p in ParentProfileSchema, on: e.parent_id == p.id)
    |> select([e, p], p.identity_id)
    |> distinct(true)
    |> Repo.all()
  end

  @impl true
  def enrolled?(program_id, identity_id) when is_binary(program_id) and is_binary(identity_id) do
    EnrollmentQueries.base()
    |> EnrollmentQueries.by_program(program_id)
    |> EnrollmentQueries.active_only()
    |> join(:inner, [e], p in ParentProfileSchema, on: e.parent_id == p.id)
    |> where([e, p], p.identity_id == ^identity_id)
    |> Repo.exists?()
  end
end
