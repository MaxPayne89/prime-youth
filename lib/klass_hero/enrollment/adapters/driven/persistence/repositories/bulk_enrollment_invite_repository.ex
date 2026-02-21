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
  - `{:error, changeset}` — first failing changeset (entire batch rolled back)
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

      {:error, {:invite, _index}, changeset, _changes} ->
        Logger.warning("[BulkEnrollmentInvite.Repository] Batch insert failed",
          errors: inspect(changeset.errors)
        )

        {:error, changeset}
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
end
