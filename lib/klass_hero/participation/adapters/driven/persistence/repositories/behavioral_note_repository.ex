defmodule KlassHero.Participation.Adapters.Driven.Persistence.Repositories.BehavioralNoteRepository do
  @moduledoc """
  Ecto-based implementation of the behavioral note repository.

  Implements the ForManagingBehavioralNotes port using PostgreSQL via Ecto.
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForManagingBehavioralNotes

  alias KlassHero.Participation.Adapters.Driven.Persistence.Mappers.BehavioralNoteMapper
  alias KlassHero.Participation.Adapters.Driven.Persistence.Queries.BehavioralNoteQueries
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.BehavioralNoteSchema
  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Repo

  @impl true
  def create(%BehavioralNote{} = note) do
    attrs = BehavioralNoteMapper.to_persistence(note)

    attrs
    |> BehavioralNoteSchema.create_changeset()
    |> Repo.insert()
    |> handle_insert_result()
  end

  @impl true
  def get_by_id(id) when is_binary(id) do
    case Repo.get(BehavioralNoteSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, BehavioralNoteMapper.to_domain(schema)}
    end
  end

  @impl true
  def update(%BehavioralNote{} = note) do
    case Repo.get(BehavioralNoteSchema, note.id) do
      nil ->
        {:error, :not_found}

      schema ->
        attrs = BehavioralNoteMapper.update_schema(schema, note)

        schema
        |> BehavioralNoteSchema.update_changeset(attrs)
        |> Repo.update()
        |> handle_update_result()
    end
  end

  @impl true
  def list_pending_by_parent(parent_id) when is_binary(parent_id) do
    BehavioralNoteQueries.base()
    |> BehavioralNoteQueries.by_parent(parent_id)
    |> BehavioralNoteQueries.pending()
    |> BehavioralNoteQueries.order_by_submitted_desc()
    |> Repo.all()
    |> Enum.map(&BehavioralNoteMapper.to_domain/1)
  end

  @impl true
  def list_approved_by_child(child_id) when is_binary(child_id) do
    BehavioralNoteQueries.base()
    |> BehavioralNoteQueries.by_child(child_id)
    |> BehavioralNoteQueries.approved()
    |> BehavioralNoteQueries.order_by_submitted_desc()
    |> Repo.all()
    |> Enum.map(&BehavioralNoteMapper.to_domain/1)
  end

  @impl true
  def list_by_records_and_provider(record_ids, provider_id)
      when is_list(record_ids) and is_binary(provider_id) do
    BehavioralNoteQueries.base()
    |> BehavioralNoteQueries.by_participation_records(record_ids)
    |> BehavioralNoteQueries.by_provider(provider_id)
    |> Repo.all()
    |> Enum.map(&BehavioralNoteMapper.to_domain/1)
  end

  @impl true
  def get_by_participation_record_and_provider(participation_record_id, provider_id)
      when is_binary(participation_record_id) and is_binary(provider_id) do
    result =
      BehavioralNoteQueries.base()
      |> BehavioralNoteQueries.by_participation_record(participation_record_id)
      |> BehavioralNoteQueries.by_provider(provider_id)
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      schema -> {:ok, BehavioralNoteMapper.to_domain(schema)}
    end
  end

  defp handle_insert_result({:ok, schema}) do
    {:ok, BehavioralNoteMapper.to_domain(schema)}
  end

  defp handle_insert_result({:error, %Ecto.Changeset{errors: errors}}) do
    # Trigger: unique constraint violation on [participation_record_id, provider_id]
    # Why: one note per provider per participation record
    # Outcome: return domain-specific error atom
    if has_unique_constraint_error?(errors) do
      {:error, :duplicate_note}
    else
      {:error, :validation_failed}
    end
  end

  defp handle_update_result({:ok, schema}) do
    {:ok, BehavioralNoteMapper.to_domain(schema)}
  end

  defp handle_update_result({:error, %Ecto.Changeset{}}) do
    {:error, :validation_failed}
  end

  defp has_unique_constraint_error?(errors) do
    Enum.any?(errors, fn
      {_field, {_msg, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end
end
