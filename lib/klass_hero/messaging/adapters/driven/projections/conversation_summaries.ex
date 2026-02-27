defmodule KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries do
  @moduledoc """
  Event-driven projection maintaining the `conversation_summaries` read table.

  This GenServer subscribes to Messaging integration events and keeps the
  denormalized `conversation_summaries` table in sync with the write model.
  On startup it bootstraps from the write tables (`conversations`,
  `conversation_participants`, `messages`, `users`), then incrementally
  applies changes as events arrive.

  ## Architecture

  This is a "driven adapter" in the Ports & Adapters architecture — it's
  driven by integration events from the Messaging context. The read-side
  repository (`ConversationSummariesRepository`) queries the table this
  projection writes.

  ## Startup Behavior

  On init, the GenServer:
  1. Subscribes to all relevant Messaging integration event topics
  2. Uses `handle_continue(:bootstrap)` to project all existing conversations
     into the read table

  ## Event Handling

  - `:conversation_created` — inserts one row per participant
  - `:message_sent` — updates latest_message fields, increments unread_count
    for non-sender participants
  - `:messages_read` — resets unread_count to 0, updates last_read_at
  - `:conversation_archived` — sets archived_at for all rows of a conversation
  - `:conversations_archived` — same as above but for multiple conversations
  - `:message_data_anonymized` — updates other_participant_name to "Deleted User"
    for rows where the anonymized user was the other participant
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.Accounts.User
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @conversation_created_topic "integration:messaging:conversation_created"
  @message_sent_topic "integration:messaging:message_sent"
  @messages_read_topic "integration:messaging:messages_read"
  @conversation_archived_topic "integration:messaging:conversation_archived"
  @conversations_archived_topic "integration:messaging:conversations_archived"
  @message_data_anonymized_topic "integration:messaging:message_data_anonymized"

  # Client API

  @doc """
  Starts the ConversationSummaries projection GenServer.

  ## Options

  - `:name` - Process name (defaults to `__MODULE__`)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Trigger: GenServer is starting
    # Why: subscribe to events before bootstrapping to avoid missing events
    #      that arrive between bootstrap completion and subscription
    # Outcome: subscribed to all six relevant topics
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @conversation_created_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @message_sent_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @messages_read_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @conversation_archived_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @conversations_archived_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @message_data_anonymized_topic)

    {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # Trigger: GenServer initialization complete
    # Why: project all existing conversations from write tables into read table
    # Outcome: conversation_summaries table populated with current data
    count = bootstrap_from_write_tables()

    Logger.info("ConversationSummaries projection started", count: count)

    {:noreply, %{state | bootstrapped: true}}
  end

  # Trigger: Received a conversation_created integration event
  # Why: a new conversation was created, each participant needs a summary row
  # Outcome: one row per participant inserted into conversation_summaries
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :conversation_created} = event},
        state
      ) do
    Logger.debug("ConversationSummaries projecting conversation_created",
      conversation_id: event.entity_id,
      event_id: event.event_id
    )

    project_conversation_created(event)
    {:noreply, state}
  end

  # Trigger: Received a message_sent integration event
  # Why: latest message fields must be updated, unread_count incremented for non-senders
  # Outcome: all summary rows for this conversation updated
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :message_sent} = event},
        state
      ) do
    Logger.debug("ConversationSummaries projecting message_sent",
      conversation_id: event.entity_id,
      event_id: event.event_id
    )

    project_message_sent(event)
    {:noreply, state}
  end

  # Trigger: Received a messages_read integration event
  # Why: the user has read all messages, unread_count should be reset
  # Outcome: summary row for {conversation_id, user_id} updated
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :messages_read} = event},
        state
      ) do
    Logger.debug("ConversationSummaries projecting messages_read",
      conversation_id: event.entity_id,
      event_id: event.event_id
    )

    project_messages_read(event)
    {:noreply, state}
  end

  # Trigger: Received a conversation_archived integration event
  # Why: conversation is being archived, all summary rows must reflect this
  # Outcome: archived_at set for all rows of the conversation
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :conversation_archived} = event},
        state
      ) do
    Logger.debug("ConversationSummaries projecting conversation_archived",
      conversation_id: event.entity_id,
      event_id: event.event_id
    )

    project_conversation_archived(event)
    {:noreply, state}
  end

  # Trigger: Received a conversations_archived integration event (bulk)
  # Why: multiple conversations archived at once, all summary rows must reflect this
  # Outcome: archived_at set for all rows of the affected conversations
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :conversations_archived} = event},
        state
      ) do
    Logger.debug("ConversationSummaries projecting conversations_archived",
      event_id: event.event_id
    )

    project_conversations_archived(event)
    {:noreply, state}
  end

  # Trigger: Received a message_data_anonymized integration event
  # Why: a user's data was anonymized (GDPR), their display name must be replaced
  # Outcome: other_participant_name set to "Deleted User" for affected rows
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :message_data_anonymized} = event},
        state
      ) do
    Logger.debug("ConversationSummaries projecting message_data_anonymized",
      user_id: event.entity_id,
      event_id: event.event_id
    )

    project_message_data_anonymized(event)
    {:noreply, state}
  end

  # Catch-all for unhandled messages — logged so misrouted events are traceable
  @impl true
  def handle_info(msg, state) do
    Logger.debug("ConversationSummaries received unexpected message",
      message: inspect(msg, limit: 200)
    )

    {:noreply, state}
  end

  # Private Functions — Bootstrap

  # Trigger: bootstrap phase — read table may be empty or stale
  # Why: cold start recovery — populate read table from authoritative write tables
  # Outcome: conversation_summaries contains one row per (conversation, participant)
  defp bootstrap_from_write_tables do
    conversations =
      from(c in ConversationSchema,
        preload: [:participants, :messages]
      )
      |> Repo.all()

    if conversations == [] do
      0
    else
      # Trigger: need user names to populate other_participant_name
      # Why: direct conversations show the other participant's display name
      # Outcome: user_id -> name lookup map built from users table
      all_user_ids =
        conversations
        |> Enum.flat_map(fn c -> Enum.map(c.participants, & &1.user_id) end)
        |> Enum.uniq()

      user_names = fetch_user_names(all_user_ids)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        Enum.flat_map(conversations, fn conversation ->
          build_conversation_entries(conversation, user_names, now)
        end)

      if entries == [] do
        0
      else
        # Trigger: summaries may already exist from a previous run
        # Why: upsert avoids duplicate key errors while keeping data fresh
        # Outcome: all summaries projected, preserving original inserted_at on conflicts
        {count, _} =
          Repo.insert_all(ConversationSummarySchema, entries,
            on_conflict: {:replace_all_except, [:id, :inserted_at]},
            conflict_target: [:conversation_id, :user_id]
          )

        count
      end
    end
  end

  defp build_conversation_entries(conversation, user_names, now) do
    active_participants = Enum.filter(conversation.participants, &is_nil(&1.left_at))
    participant_count = length(active_participants)
    latest_message = find_latest_message(conversation.messages)

    Enum.map(active_participants, fn participant ->
      build_summary_entry(
        conversation,
        participant,
        active_participants,
        user_names,
        latest_message,
        participant_count,
        now
      )
    end)
  end

  defp build_summary_entry(
         conversation,
         participant,
         active_participants,
         user_names,
         latest_message,
         participant_count,
         now
       ) do
    other_name =
      resolve_other_participant_name(
        conversation.type,
        participant.user_id,
        active_participants,
        user_names
      )

    unread_count =
      compute_unread_count(
        conversation.messages,
        participant.last_read_at,
        participant.user_id
      )

    %{
      id: Ecto.UUID.generate(),
      conversation_id: conversation.id,
      user_id: participant.user_id,
      conversation_type: conversation.type,
      provider_id: conversation.provider_id,
      program_id: conversation.program_id,
      subject: conversation.subject,
      other_participant_name: other_name,
      participant_count: participant_count,
      latest_message_content: latest_message && latest_message.content,
      latest_message_sender_id: latest_message && latest_message.sender_id,
      latest_message_at: latest_message && latest_message.inserted_at,
      unread_count: unread_count,
      last_read_at: participant.last_read_at,
      archived_at: conversation.archived_at,
      inserted_at: now,
      updated_at: now
    }
  end

  # Private Functions — Event Projections

  # Trigger: conversation_created event received
  # Why: each participant needs their own summary row with resolved display names
  # Outcome: one row per participant inserted (upsert for idempotency)
  defp project_conversation_created(event) do
    payload = event.payload
    conversation_id = payload.conversation_id
    participant_ids = Map.get(payload, :participant_ids, [])
    conversation_type = Map.get(payload, :type, "direct")
    provider_id = Map.get(payload, :provider_id)
    program_id = Map.get(payload, :program_id)
    subject = Map.get(payload, :subject)
    participant_count = length(participant_ids)

    user_names = fetch_user_names(participant_ids)

    Enum.each(participant_ids, fn user_id ->
      other_name =
        resolve_other_name_from_ids(
          conversation_type,
          user_id,
          participant_ids,
          user_names
        )

      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: conversation_id,
        user_id: user_id,
        conversation_type: conversation_type,
        provider_id: provider_id,
        program_id: program_id,
        subject: subject,
        other_participant_name: other_name,
        participant_count: participant_count,
        unread_count: 0
      }

      %ConversationSummarySchema{}
      |> Ecto.Changeset.change(attrs)
      |> Repo.insert!(
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:conversation_id, :user_id]
      )
    end)
  end

  # Trigger: message_sent event received
  # Why: all participants need updated latest_message fields;
  #      non-sender participants need incremented unread_count
  # Outcome: bulk update for latest_message fields + selective unread increment
  defp project_message_sent(event) do
    payload = event.payload
    conversation_id = payload.conversation_id
    sender_id = payload.sender_id
    content = Map.get(payload, :content)
    sent_at = Map.get(payload, :sent_at)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Update latest_message fields for all participants of this conversation
    from(s in ConversationSummarySchema,
      where: s.conversation_id == ^conversation_id
    )
    |> Repo.update_all(
      set: [
        latest_message_content: content,
        latest_message_sender_id: sender_id,
        latest_message_at: sent_at,
        updated_at: now
      ]
    )

    # Increment unread_count only for non-sender participants
    from(s in ConversationSummarySchema,
      where: s.conversation_id == ^conversation_id and s.user_id != ^sender_id
    )
    |> Repo.update_all(inc: [unread_count: 1])
  end

  # Trigger: messages_read event received
  # Why: user has caught up on messages, unread_count should be zeroed
  # Outcome: single row updated with unread_count=0 and last_read_at
  defp project_messages_read(event) do
    payload = event.payload
    conversation_id = payload.conversation_id
    user_id = payload.user_id
    read_at = Map.get(payload, :read_at)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(s in ConversationSummarySchema,
      where: s.conversation_id == ^conversation_id and s.user_id == ^user_id
    )
    |> Repo.update_all(
      set: [
        unread_count: 0,
        last_read_at: read_at,
        updated_at: now
      ]
    )
  end

  # Trigger: conversation_archived event received
  # Why: conversation is being archived, all summary rows must reflect this
  # Outcome: archived_at set on all rows for this conversation
  defp project_conversation_archived(event) do
    payload = event.payload
    conversation_id = payload.conversation_id
    archived_at = Map.get(payload, :archived_at)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(s in ConversationSummarySchema,
      where: s.conversation_id == ^conversation_id
    )
    |> Repo.update_all(
      set: [
        archived_at: archived_at,
        updated_at: now
      ]
    )
  end

  # Trigger: conversations_archived bulk event received
  # Why: multiple conversations archived at once (e.g. program ended)
  # Outcome: archived_at set on all rows for all affected conversations
  defp project_conversations_archived(event) do
    payload = event.payload
    conversation_ids = Map.get(payload, :conversation_ids, [])
    archived_at = Map.get(payload, :archived_at)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if conversation_ids != [] do
      from(s in ConversationSummarySchema,
        where: s.conversation_id in ^conversation_ids
      )
      |> Repo.update_all(
        set: [
          archived_at: archived_at,
          updated_at: now
        ]
      )
    end
  end

  # Trigger: message_data_anonymized event received (GDPR deletion)
  # Why: the anonymized user's name must no longer appear in other participants' summaries
  # Outcome: rows where the anonymized user is the "other participant" get name replaced
  defp project_message_data_anonymized(event) do
    anonymized_user_id = event.payload.user_id
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Trigger: find all conversations where the anonymized user is a participant
    # Why: we need to update the other_participant_name in rows belonging to
    #      the *other* participants (not the anonymized user themselves)
    # Outcome: "Deleted User" shown where the anonymized user was the counterpart
    conversation_ids =
      from(s in ConversationSummarySchema,
        where: s.user_id == ^anonymized_user_id,
        select: s.conversation_id
      )
      |> Repo.all()

    if conversation_ids != [] do
      from(s in ConversationSummarySchema,
        where:
          s.conversation_id in ^conversation_ids and
            s.user_id != ^anonymized_user_id
      )
      |> Repo.update_all(
        set: [
          other_participant_name: "Deleted User",
          updated_at: now
        ]
      )
    end
  end

  # Private Functions — Helpers

  # Trigger: need to look up display names for a set of user IDs
  # Why: conversation summaries show the other participant's name
  # Outcome: map of user_id -> display name (name or email fallback)
  defp fetch_user_names(user_ids) when is_list(user_ids) and user_ids != [] do
    from(u in User,
      where: u.id in ^user_ids,
      select: {u.id, u.name, u.email}
    )
    |> Repo.all()
    |> Map.new(fn {id, name, email} -> {id, name || email} end)
  end

  defp fetch_user_names(_), do: %{}

  # Trigger: resolving other participant name for bootstrap (has ParticipantSchema structs)
  # Why: for direct conversations, each user sees the other's name
  # Outcome: display name of the other participant, or nil for broadcasts
  defp resolve_other_participant_name("direct", user_id, participants, user_names) do
    case Enum.find(participants, fn p -> p.user_id != user_id end) do
      nil -> nil
      other -> Map.get(user_names, other.user_id)
    end
  end

  defp resolve_other_participant_name(_type, _user_id, _participants, _user_names), do: nil

  # Trigger: resolving other participant name for events (has bare user_id list)
  # Why: conversation_created event carries participant_ids, not full structs
  # Outcome: display name of the other participant, or nil for broadcasts
  defp resolve_other_name_from_ids("direct", user_id, participant_ids, user_names) do
    case Enum.find(participant_ids, fn id -> id != user_id end) do
      nil -> nil
      other_id -> Map.get(user_names, other_id)
    end
  end

  defp resolve_other_name_from_ids(_type, _user_id, _participant_ids, _user_names), do: nil

  # Trigger: finding the most recent message for a conversation during bootstrap
  # Why: summary row needs the latest message content, sender, and timestamp
  # Outcome: the most recent MessageSchema or nil if no messages
  defp find_latest_message([]), do: nil

  defp find_latest_message(messages) do
    Enum.max_by(messages, & &1.inserted_at, DateTime)
  end

  # Trigger: computing how many messages are unread for a participant
  # Why: unread_count = messages from OTHER users after last_read_at.
  #      A user's own messages should never count as unread.
  # Outcome: integer count of unread messages (excluding own messages)
  defp compute_unread_count(messages, nil, user_id) do
    Enum.count(messages, fn msg -> msg.sender_id != user_id end)
  end

  defp compute_unread_count(messages, last_read_at, user_id) do
    Enum.count(messages, fn msg ->
      msg.sender_id != user_id and DateTime.after?(msg.inserted_at, last_read_at)
    end)
  end
end
