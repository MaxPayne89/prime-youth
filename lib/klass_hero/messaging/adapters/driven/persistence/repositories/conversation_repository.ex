defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationRepository do
  @moduledoc """
  Ecto-based repository for managing conversations.

  Implements ForManagingConversations port.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForManagingConversations

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.ConversationMapper
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationQueries
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema
  alias KlassHero.Repo

  require Logger

  @impl true
  def create(attrs) do
    schema_attrs = ConversationMapper.to_create_attrs(attrs)

    %ConversationSchema{}
    |> ConversationSchema.create_changeset(schema_attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        conversation = ConversationMapper.to_domain(schema)

        Logger.debug("Created conversation",
          conversation_id: conversation.id,
          type: conversation.type
        )

        {:ok, conversation}

      {:error, %Ecto.Changeset{errors: errors}} = result ->
        if Keyword.has_key?(errors, :program_id) do
          {:error, :duplicate_broadcast}
        else
          result
        end
    end
  end

  @impl true
  def get_by_id(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    ConversationQueries.base()
    |> ConversationQueries.by_id(id)
    |> ConversationQueries.preload_assocs(preloads)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> {:ok, ConversationMapper.to_domain(schema)}
    end
  end

  @impl true
  def find_direct_conversation(provider_id, user_id) do
    ConversationQueries.find_direct(provider_id, user_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> {:ok, ConversationMapper.to_domain(schema)}
    end
  end

  @impl true
  def list_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    results =
      ConversationQueries.base()
      |> ConversationQueries.active_only()
      |> ConversationQueries.where_user_is_participant(user_id)
      |> ConversationQueries.with_unread_count(user_id)
      |> ConversationQueries.order_by_recent_message()
      |> ConversationQueries.paginate(opts)
      |> Repo.all()

    has_more = length(results) > limit
    conversations = results |> Enum.take(limit) |> Enum.map(&ConversationMapper.to_domain/1)

    {:ok, conversations, has_more}
  end

  @impl true
  def list_for_provider(provider_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    type = Keyword.get(opts, :type)

    query =
      ConversationQueries.base()
      |> ConversationQueries.by_provider(provider_id)
      |> ConversationQueries.active_only()
      |> ConversationQueries.order_by_recent_message()
      |> ConversationQueries.paginate(opts)

    query = if type, do: ConversationQueries.by_type(query, type), else: query

    results = Repo.all(query)
    has_more = length(results) > limit
    conversations = results |> Enum.take(limit) |> Enum.map(&ConversationMapper.to_domain/1)

    {:ok, conversations, has_more}
  end

  @impl true
  def archive(conversation) do
    now = DateTime.utc_now()
    retention_until = DateTime.add(now, 30, :day)

    ConversationSchema
    |> Repo.get(conversation.id)
    |> case do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> ConversationSchema.archive_changeset(%{
          archived_at: now,
          retention_until: retention_until
        })
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            Logger.info("Archived conversation", conversation_id: conversation.id)
            {:ok, ConversationMapper.to_domain(updated)}

          error ->
            error
        end
    end
  end

  @impl true
  def delete_expired(before) do
    {count, _} =
      ConversationQueries.base()
      |> ConversationQueries.archived_only()
      |> ConversationQueries.retention_expired(before)
      |> Repo.delete_all()

    Logger.info("Deleted expired conversations", count: count)
    {:ok, count}
  end
end
