defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository do
  @moduledoc """
  Repository implementation for bulk enrollment invite persistence.

  Implements the ForStoringBulkEnrollmentInvites port with:
  - Atomic batch insert via Ecto.Multi
  - Duplicate-detection query returning MapSet of natural keys

  All rows in a batch share a single transaction boundary.
  If any row fails changeset validation, the entire batch rolls back.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForStoringBulkEnrollmentInvites

  import Ecto.Query

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.BulkEnrollmentInviteMapper,
    as: Mapper

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Repo

  require Logger

  @impl true
  @doc """
  Inserts all invite records atomically in a single transaction.

  Each row passes through `BulkEnrollmentInviteSchema.import_changeset/2`,
  which validates required fields and excludes lifecycle columns.

  Returns:
  - `{:ok, non_neg_integer()}` — count of created records
  - `{:error, {index, changeset}}` — 0-based row index and first failing changeset (entire batch rolled back)
  """
  def create_batch([]), do: {:ok, 0}

  def create_batch(rows) when is_list(rows) do
    rows
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {attrs, index}, multi ->
      changeset =
        BulkEnrollmentInviteSchema.import_changeset(%BulkEnrollmentInviteSchema{}, attrs)

      Ecto.Multi.insert(multi, {:invite, index}, changeset)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, results} ->
        count = map_size(results)

        Logger.info("[BulkEnrollmentInvite.Repository] Batch created",
          count: count
        )

        {:ok, count}

      {:error, {:invite, index}, changeset, _changes} ->
        Logger.error("[BulkEnrollmentInvite.Repository] Batch insert failed",
          row_index: index,
          batch_size: length(rows),
          errors: inspect(changeset.errors)
        )

        {:error, {index, changeset}}
    end
  end

  @impl true
  @doc """
  Returns existing invite keys for the given program IDs.

  Used for duplicate detection before batch insert. Keys are
  `{program_id, guardian_email, child_first_name, child_last_name}` tuples
  with email lowercased for case-insensitive comparison.

  Returns an empty MapSet when given an empty list.
  """
  def list_existing_keys_for_programs([]), do: MapSet.new()

  def list_existing_keys_for_programs(program_ids) when is_list(program_ids) do
    BulkEnrollmentInviteSchema
    |> where([i], i.program_id in ^program_ids)
    |> select([i], {i.program_id, i.guardian_email, i.child_first_name, i.child_last_name})
    |> Repo.all()
    |> MapSet.new(fn {pid, email, first, last} ->
      {pid, String.downcase(email), String.downcase(first), String.downcase(last)}
    end)
  end

  @impl true
  @doc """
  Retrieves a single invite by its ID.

  Returns the invite struct or nil if not found.
  """
  def get_by_id(id) when is_binary(id) do
    case Repo.get(BulkEnrollmentInviteSchema, id) do
      nil -> nil
      schema -> Mapper.to_domain(schema)
    end
  end

  @impl true
  @doc """
  Returns pending invites that have not yet been assigned an invite token.

  Filters by program IDs, status "pending", and nil invite_token.
  Returns an empty list when given an empty list of program IDs.
  """
  def list_pending_without_token([]), do: []

  def list_pending_without_token(program_ids) when is_list(program_ids) do
    BulkEnrollmentInviteSchema
    |> where([i], i.program_id in ^program_ids)
    |> where([i], i.status == "pending")
    |> where([i], is_nil(i.invite_token))
    |> Repo.all()
    |> Mapper.to_domain_list()
  end

  @impl true
  @doc """
  Assigns invite tokens to multiple invites in bulk.

  Accepts a list of `{invite_id, token}` tuples. Each invite is updated
  individually within a reduce. Returns `{:ok, count}` with the total
  number of rows updated.
  """
  def bulk_assign_tokens([]), do: {:ok, 0}

  def bulk_assign_tokens(id_token_pairs) when is_list(id_token_pairs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Trigger: N pairs would cause N individual UPDATE queries (N+1 problem)
    # Why: single UPDATE...FROM (VALUES ...) batches all token assignments into one round-trip
    # Outcome: exactly 1 SQL statement regardless of batch size
    {values_clause, params} = build_values_clause(id_token_pairs, now)

    sql = """
    UPDATE bulk_enrollment_invites AS b
    SET invite_token = v.token, updated_at = v.updated_at
    FROM (VALUES #{values_clause}) AS v(id, token, updated_at)
    WHERE b.id = v.id::uuid
    """

    case Repo.query(sql, params) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_values_clause(pairs, now) do
    {fragments, params, _idx} =
      Enum.reduce(pairs, {[], [], 1}, fn {id, token}, {frags, params, idx} ->
        frag = "($#{idx}, $#{idx + 1}, $#{idx + 2}::timestamp)"
        {[frag | frags], params ++ [id, token, now], idx + 3}
      end)

    {fragments |> Enum.reverse() |> Enum.join(", "), params}
  end

  @impl true
  @doc """
  Transitions an invite's status using the schema's state machine.

  Delegates to `BulkEnrollmentInviteSchema.transition_changeset/2` for
  validation, then persists the update.
  """
  def transition_status(%{id: id}, attrs) when is_map(attrs) do
    # Trigger: domain model passed in — must refetch schema for Ecto changeset
    # Why: domain models are pure structs without Ecto metadata
    # Outcome: load schema by ID, apply transition changeset, map result back
    case Repo.get(BulkEnrollmentInviteSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> BulkEnrollmentInviteSchema.transition_changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_schema} -> {:ok, Mapper.to_domain(updated_schema)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end
end
