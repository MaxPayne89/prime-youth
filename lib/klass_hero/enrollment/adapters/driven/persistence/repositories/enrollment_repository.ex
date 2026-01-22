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

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Queries.EnrollmentQueries
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.EctoErrorHelpers

  require Logger

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
end
