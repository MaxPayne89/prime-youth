defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository do
  @moduledoc """
  Ecto-based repository for managing conversation participants.

  Implements ForManagingParticipants port.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForManagingParticipants

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.ParticipantMapper
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ParticipantSchema
  alias KlassHero.Repo

  require Logger

  @impl true
  def add(attrs) do
    schema_attrs = ParticipantMapper.to_create_attrs(attrs)

    %ParticipantSchema{}
    |> ParticipantSchema.create_changeset(schema_attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        participant = ParticipantMapper.to_domain(schema)

        Logger.debug("Added participant",
          participant_id: participant.id,
          conversation_id: participant.conversation_id,
          user_id: participant.user_id
        )

        {:ok, participant}

      {:error, %Ecto.Changeset{} = changeset} = result ->
        # Check specifically for unique constraint violation (already participant)
        case changeset.errors[:conversation_id] do
          {"has already been taken", _} -> {:error, :already_participant}
          _ -> result
        end
    end
  end

  @impl true
  def get(conversation_id, user_id) do
    from(p in ParticipantSchema,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> {:ok, ParticipantMapper.to_domain(schema)}
    end
  end

  @impl true
  def list_for_conversation(conversation_id) do
    from(p in ParticipantSchema,
      where: p.conversation_id == ^conversation_id and is_nil(p.left_at),
      order_by: [asc: p.joined_at]
    )
    |> Repo.all()
    |> Enum.map(&ParticipantMapper.to_domain/1)
  end

  @impl true
  def mark_as_read(conversation_id, user_id, read_at) do
    from(p in ParticipantSchema,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> ParticipantSchema.mark_read_changeset(%{last_read_at: read_at})
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            Logger.debug("Marked as read",
              conversation_id: conversation_id,
              user_id: user_id,
              read_at: read_at
            )

            {:ok, ParticipantMapper.to_domain(updated)}

          error ->
            error
        end
    end
  end

  @impl true
  def leave(conversation_id, user_id) do
    now = DateTime.utc_now()

    from(p in ParticipantSchema,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> ParticipantSchema.leave_changeset(%{left_at: now})
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            Logger.info("Participant left conversation",
              conversation_id: conversation_id,
              user_id: user_id
            )

            {:ok, ParticipantMapper.to_domain(updated)}

          error ->
            error
        end
    end
  end

  @impl true
  def is_participant?(conversation_id, user_id) do
    from(p in ParticipantSchema,
      where:
        p.conversation_id == ^conversation_id and
          p.user_id == ^user_id and
          is_nil(p.left_at)
    )
    |> Repo.exists?()
  end

  @impl true
  def add_batch(conversation_id, user_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(user_ids, fn user_id ->
        %{
          id: Ecto.UUID.generate(),
          conversation_id: conversation_id,
          user_id: user_id,
          joined_at: now,
          inserted_at: now,
          updated_at: now
        }
      end)

    {_count, schemas} =
      Repo.insert_all(ParticipantSchema, entries,
        returning: true,
        on_conflict: :nothing,
        conflict_target: [:conversation_id, :user_id]
      )

    participants = Enum.map(schemas, &ParticipantMapper.to_domain/1)

    Logger.debug("Added batch of participants",
      conversation_id: conversation_id,
      count: length(participants)
    )

    {:ok, participants}
  end
end
