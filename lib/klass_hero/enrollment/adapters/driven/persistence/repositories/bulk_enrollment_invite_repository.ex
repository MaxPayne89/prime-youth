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
    Repo.get(BulkEnrollmentInviteSchema, id)
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

    count =
      Enum.reduce(id_token_pairs, 0, fn {id, token}, acc ->
        {rows_updated, _} =
          BulkEnrollmentInviteSchema
          |> where([i], i.id == ^id)
          |> Repo.update_all(set: [invite_token: token, updated_at: now])

        acc + rows_updated
      end)

    {:ok, count}
  end

  @impl true
  @doc """
  Transitions an invite's status using the schema's state machine.

  Delegates to `BulkEnrollmentInviteSchema.transition_changeset/2` for
  validation, then persists the update.
  """
  def transition_status(%BulkEnrollmentInviteSchema{} = invite, attrs) when is_map(attrs) do
    invite
    |> BulkEnrollmentInviteSchema.transition_changeset(attrs)
    |> Repo.update()
  end
end
