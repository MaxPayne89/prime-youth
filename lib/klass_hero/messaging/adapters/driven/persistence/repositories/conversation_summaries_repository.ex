defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationSummariesRepository do
  @moduledoc """
  Read repository for the conversation_summaries denormalized read model.

  Queries the conversation_summaries table and returns ConversationSummary DTOs.
  This is the read side — writes are handled by the ConversationSummariesProjection.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForListingConversationSummaries

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Messaging.Domain.ReadModels.ConversationSummary
  alias KlassHero.Repo

  require Logger

  @default_limit 25

  @impl true
  def list_for_user(user_id, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)

    Logger.debug("[ConversationSummariesRepository] Listing summaries for user",
      user_id: user_id,
      limit: limit
    )

    # Trigger: fetch limit + 1 rows
    # Why: determines if more pages exist without a separate COUNT query
    # Outcome: sets has_more flag and trims result to requested limit
    schemas =
      from(s in ConversationSummarySchema,
        where: s.user_id == ^user_id and is_nil(s.archived_at),
        order_by: [desc: s.latest_message_at, desc: s.id],
        limit: ^(limit + 1)
      )
      |> Repo.all()

    {items, has_more} =
      if length(schemas) > limit do
        {Enum.take(schemas, limit), true}
      else
        {schemas, false}
      end

    summaries = Enum.map(items, &to_dto/1)

    Logger.debug("[ConversationSummariesRepository] Retrieved summaries",
      user_id: user_id,
      returned_count: length(summaries),
      has_more: has_more
    )

    {:ok, summaries, has_more}
  end

  @impl true
  def get_total_unread_count(user_id) do
    Logger.debug("[ConversationSummariesRepository] Getting total unread count",
      user_id: user_id
    )

    count =
      from(s in ConversationSummarySchema,
        where: s.user_id == ^user_id and is_nil(s.archived_at),
        select: coalesce(sum(s.unread_count), 0)
      )
      |> Repo.one()

    Logger.debug("[ConversationSummariesRepository] Total unread count",
      user_id: user_id,
      count: count
    )

    count
  end

  defp to_dto(%ConversationSummarySchema{} = schema) do
    ConversationSummary.new(%{
      id: schema.id,
      conversation_id: schema.conversation_id,
      user_id: schema.user_id,
      conversation_type: schema.conversation_type,
      provider_id: schema.provider_id,
      program_id: schema.program_id,
      subject: schema.subject,
      other_participant_name: schema.other_participant_name,
      participant_count: schema.participant_count,
      latest_message_content: schema.latest_message_content,
      latest_message_sender_id: schema.latest_message_sender_id,
      latest_message_at: schema.latest_message_at,
      unread_count: schema.unread_count,
      last_read_at: schema.last_read_at,
      archived_at: schema.archived_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end
end
