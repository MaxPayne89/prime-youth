defmodule PrimeYouth.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository do
  @moduledoc """
  Ecto-based implementation of the participation record repository.

  Implements the ForManagingParticipation port using PostgreSQL via Ecto.
  """

  @behaviour PrimeYouth.Participation.Domain.Ports.ForManagingParticipation

  import Ecto.Query

  alias Ecto.Multi
  alias PrimeYouth.Participation.Adapters.Driven.Persistence.Mappers.ParticipationRecordMapper
  alias PrimeYouth.Participation.Adapters.Driven.Persistence.Queries.ParticipationQueries
  alias PrimeYouth.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema
  alias PrimeYouth.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias PrimeYouth.Participation.Domain.Models.ParticipationRecord
  alias PrimeYouth.Repo
  alias PrimeYouthWeb.ErrorIds

  @impl true
  def create(%ParticipationRecord{} = record) do
    attrs = ParticipationRecordMapper.to_persistence(record)

    attrs
    |> ParticipationRecordSchema.create_changeset()
    |> Repo.insert()
    |> handle_insert_result()
  end

  @impl true
  def get_by_id(id) when is_binary(id) do
    case Repo.get(ParticipationRecordSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, ParticipationRecordMapper.to_domain(schema)}
    end
  end

  @impl true
  def list_by_session(session_id) when is_binary(session_id) do
    ParticipationQueries.base()
    |> ParticipationQueries.by_session(session_id)
    |> ParticipationQueries.order_by_inserted_desc()
    |> Repo.all()
    |> Enum.map(&ParticipationRecordMapper.to_domain/1)
  end

  @impl true
  def list_by_child(child_id) when is_binary(child_id) do
    ParticipationQueries.base()
    |> ParticipationQueries.by_child(child_id)
    |> ParticipationQueries.preload_session()
    |> ParticipationQueries.order_by_inserted_desc()
    |> Repo.all()
    |> Enum.map(&ParticipationRecordMapper.to_domain/1)
  end

  @impl true
  def list_by_child_and_date_range(child_id, start_date, end_date) when is_binary(child_id) do
    ParticipationQueries.base()
    |> ParticipationQueries.by_child(child_id)
    |> ParticipationQueries.by_date_range(start_date, end_date)
    |> ParticipationQueries.order_by_session_date_desc()
    |> Repo.all()
    |> Enum.map(&ParticipationRecordMapper.to_domain/1)
  end

  @impl true
  def list_by_children(child_ids) when is_list(child_ids) do
    ParticipationQueries.base()
    |> ParticipationQueries.by_children(child_ids)
    |> ParticipationQueries.preload_session()
    |> ParticipationQueries.order_by_inserted_desc()
    |> Repo.all()
    |> Enum.map(&ParticipationRecordMapper.to_domain/1)
  end

  @impl true
  def list_by_children_and_date_range(child_ids, start_date, end_date) when is_list(child_ids) do
    ParticipationQueries.base()
    |> ParticipationQueries.by_children(child_ids)
    |> ParticipationQueries.by_date_range(start_date, end_date)
    |> ParticipationQueries.order_by_session_date_desc()
    |> Repo.all()
    |> Enum.map(&ParticipationRecordMapper.to_domain/1)
  end

  @impl true
  def update(%ParticipationRecord{} = record) do
    case Repo.get(ParticipationRecordSchema, record.id) do
      nil ->
        {:error, :not_found}

      schema ->
        attrs = ParticipationRecordMapper.update_schema(schema, record)

        schema
        |> ParticipationRecordSchema.update_changeset(attrs)
        |> do_update()
    end
  end

  defp do_update(changeset) do
    Repo.update(changeset)
    |> handle_update_result()
  rescue
    Ecto.StaleEntryError ->
      {:error, :stale_data}
  end

  @impl true
  def create_batch(records) when is_list(records) do
    multi =
      records
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {record, index}, multi ->
        attrs = ParticipationRecordMapper.to_persistence(record)
        changeset = ParticipationRecordSchema.create_changeset(attrs)
        Multi.insert(multi, {:record, index}, changeset)
      end)

    case Repo.transaction(multi) do
      {:ok, results} ->
        records =
          results
          |> Enum.sort_by(fn {{:record, index}, _} -> index end)
          |> Enum.map(fn {_, schema} -> ParticipationRecordMapper.to_domain(schema) end)

        {:ok, records}

      {:error, _operation, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists participation records for a session with child names resolved.

  This is a convenience function that joins session data for roster display.
  """
  @spec list_by_session_with_session(String.t()) :: [
          {ParticipationRecord.t(), ProgramSessionSchema.t()}
        ]
  def list_by_session_with_session(session_id) when is_binary(session_id) do
    from(r in ParticipationRecordSchema,
      join: s in ProgramSessionSchema,
      on: r.session_id == s.id,
      where: r.session_id == ^session_id,
      order_by: [asc: r.inserted_at],
      select: {r, s}
    )
    |> Repo.all()
    |> Enum.map(fn {record_schema, session_schema} ->
      {ParticipationRecordMapper.to_domain(record_schema), session_schema}
    end)
  end

  defp handle_insert_result({:ok, schema}) do
    {:ok, ParticipationRecordMapper.to_domain(schema)}
  end

  defp handle_insert_result({:error, %Ecto.Changeset{errors: errors} = changeset}) do
    if Keyword.has_key?(errors, :session_id) &&
         match?({_, [constraint: :unique, constraint_name: _]}, errors[:session_id]) do
      {:error, :duplicate_record}
    else
      {:error, ErrorIds.participation_record_create_failed(changeset)}
    end
  end

  defp handle_update_result({:ok, schema}) do
    {:ok, ParticipationRecordMapper.to_domain(schema)}
  end

  defp handle_update_result({:error, %Ecto.Changeset{} = changeset}) do
    if changeset.errors[:lock_version] do
      {:error, :stale_data}
    else
      {:error, ErrorIds.participation_record_update_failed(changeset)}
    end
  end
end
