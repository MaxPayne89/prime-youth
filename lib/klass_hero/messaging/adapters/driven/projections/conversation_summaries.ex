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

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @user_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_users])

  @conversation_created_topic "integration:messaging:conversation_created"
  @message_sent_topic "integration:messaging:message_sent"
  @messages_read_topic "integration:messaging:messages_read"
  @conversation_archived_topic "integration:messaging:conversation_archived"
  @conversations_archived_topic "integration:messaging:conversations_archived"
  @message_data_anonymized_topic "integration:messaging:message_data_anonymized"
  @broadcast_token_regex ~r/\[broadcast:[^\]]+\]/

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

  @doc """
  Rebuilds the conversation_summaries read table from the write tables.

  Useful after seeding write tables directly (bypassing integration events).
  Blocks until the rebuild is complete.
  """
  @spec rebuild(GenServer.name()) :: :ok
  def rebuild(name \\ __MODULE__) do
    GenServer.call(name, :rebuild, :infinity)
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
    attempt_bootstrap(state)
  end

  # Trigger: external caller requests a full rebuild (e.g. after seeding)
  # Why: seeds insert into write tables without emitting integration events
  # Outcome: conversation_summaries read table refreshed from write tables
  @impl true
  def handle_call(:rebuild, _from, state) do
    count = bootstrap_from_write_tables()
    Logger.info("ConversationSummaries rebuilt", count: count)
    {:reply, :ok, %{state | bootstrapped: true}}
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
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
    Logger.warning("ConversationSummaries received unexpected message",
      message: inspect(msg, limit: 200)
    )

    {:noreply, state}
  end

  # Private Functions — Bootstrap

  # Trigger: bootstrap attempt with retry logic
  # Why: transient DB failures shouldn't crash the GenServer immediately
  # Outcome: successful bootstrap or scheduled retry (up to 3 times before crashing)
  defp attempt_bootstrap(state) do
    count = bootstrap_from_write_tables()
    Logger.info("ConversationSummaries projection started", count: count)
    {:noreply, %{state | bootstrapped: true}}
  rescue
    error ->
      retry_count = Map.get(state, :retry_count, 0) + 1

      if retry_count > 3 do
        # Trigger: exhausted retries
        # Why: persistent failure indicates real infrastructure issue
        # Outcome: crash to let supervisor handle with its own restart strategy
        reraise error, __STACKTRACE__
      else
        Logger.error("ConversationSummaries: bootstrap failed, scheduling retry",
          error: Exception.message(error),
          retry_count: retry_count
        )

        Process.send_after(self(), :retry_bootstrap, 5_000 * retry_count)
        {:noreply, Map.put(state, :retry_count, retry_count)}
      end
  end

  # Trigger: bootstrap phase — read table may be empty or stale
  # Why: cold start recovery — populate read table from authoritative write tables
  # Outcome: conversation_summaries contains one row per (conversation, participant)
  defp bootstrap_from_write_tables do
    conversations =
      from(c in ConversationSchema, preload: [:participants])
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

      # Trigger: need latest message per conversation without loading all messages
      # Why: preloading :messages loads N×M rows; this fetches N rows (one per conversation)
      # Outcome: efficient lookup map of conversation_id -> latest message fields
      conversation_ids = Enum.map(conversations, & &1.id)
      latest_messages = fetch_latest_messages(conversation_ids)

      # Trigger: need unread counts per (conversation, participant) without loading all messages
      # Why: counting in the DB is far cheaper than loading all messages into memory
      # Outcome: {conversation_id, user_id} -> unread_count lookup map
      unread_counts = fetch_unread_counts(conversations)

      # Trigger: need system note tokens per conversation for dedup tracking
      # Why: system messages with broadcast tokens must be pre-populated in the read table
      # Outcome: conversation_id -> %{token => iso8601_timestamp} lookup map
      system_notes = fetch_system_notes(conversation_ids)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        Enum.flat_map(conversations, fn conversation ->
          build_conversation_entries(
            conversation,
            user_names,
            latest_messages,
            unread_counts,
            system_notes,
            now
          )
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

  defp build_conversation_entries(
         conversation,
         user_names,
         latest_messages,
         unread_counts,
         system_notes,
         now
       ) do
    active_participants = Enum.filter(conversation.participants, &is_nil(&1.left_at))
    latest_message = Map.get(latest_messages, conversation.id)
    conv_system_notes = Map.get(system_notes, conversation.id, %{})

    Enum.map(active_participants, fn participant ->
      build_summary_entry(
        conversation,
        participant,
        active_participants,
        user_names,
        latest_message,
        unread_counts,
        conv_system_notes,
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
         unread_counts,
         conv_system_notes,
         now
       ) do
    participant_count = length(active_participants)

    other_name =
      resolve_other_participant_name(
        conversation.type,
        participant.user_id,
        active_participants,
        user_names
      )

    unread_count = Map.get(unread_counts, {conversation.id, participant.user_id}, 0)

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
      system_notes: conv_system_notes,
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
    conversation_type = payload |> Map.get(:type, "direct") |> to_string()
    provider_id = Map.get(payload, :provider_id)
    program_id = Map.get(payload, :program_id)
    subject = Map.get(payload, :subject)
    participant_count = length(participant_ids)

    user_names = fetch_user_names(participant_ids)

    # Trigger: multiple participant rows must be inserted atomically
    # Why: a mid-loop crash without a transaction leaves partial rows,
    #      resulting in some participants having summaries and others not
    # Outcome: all-or-nothing insert — either every participant gets a row or none do
    Repo.transaction(fn ->
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
    end)
  end

  # Trigger: message_sent event received
  # Why: all participants need updated latest_message fields;
  #      non-sender participants need incremented unread_count.
  #      Both updates wrapped in a transaction for atomicity — without it,
  #      a crash between the two updates leaves inconsistent read state.
  # Outcome: atomic bulk update for latest_message fields + selective unread increment
  defp project_message_sent(event) do
    payload = event.payload
    conversation_id = payload.conversation_id
    sender_id = payload.sender_id
    content = Map.get(payload, :content)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    sent_at = Map.get(payload, :sent_at) || now

    Repo.transaction(fn ->
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
    end)

    try do
      maybe_project_system_note(payload)
    rescue
      error ->
        Logger.error("Failed to project system note — will recover on next bootstrap",
          conversation_id: payload.conversation_id,
          error: Exception.message(error)
        )
    end
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

  # Private Functions — System Note Projection

  # Trigger: a message_sent event was received
  # Why: only system messages with broadcast tokens need tracking in the projection
  # Outcome: if a broadcast token is found, upsert into system_notes JSONB
  defp maybe_project_system_note(%{message_type: message_type, content: content} = payload)
       when message_type in [:system, "system"] do
    conversation_id = payload.conversation_id

    case Regex.run(@broadcast_token_regex, content || "") do
      [token] ->
        # Trigger: use event timestamp for deterministic, replay-safe values
        # Why: DateTime.utc_now() changes on each replay, causing unnecessary writes
        # Outcome: same event always produces the same JSONB value (truly idempotent)
        sent_at = Map.get(payload, :sent_at) || DateTime.utc_now()
        truncated_at = DateTime.truncate(sent_at, :second)
        token_json = %{token => DateTime.to_iso8601(truncated_at)}

        from(s in ConversationSummarySchema,
          where: s.conversation_id == ^conversation_id,
          update: [
            set: [
              system_notes:
                fragment(
                  "coalesce(system_notes, '{}')::jsonb || ?::jsonb",
                  ^token_json
                ),
              updated_at: ^truncated_at
            ]
          ]
        )
        |> Repo.update_all([])

      _ ->
        :ok
    end
  end

  defp maybe_project_system_note(_payload), do: :ok

  # Private Functions — Helpers

  # Trigger: need to look up display names for a set of user IDs
  # Why: conversation summaries show the other participant's name
  # Outcome: map of user_id -> display name (name or email fallback)
  defp fetch_user_names(user_ids) when is_list(user_ids) and user_ids != [] do
    {:ok, names} = @user_resolver.get_display_names(user_ids)
    names
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

  # Trigger: bootstrap needs latest message per conversation without loading all messages
  # Why: preloading :messages loads N×M rows; this fetches N rows (one per conversation)
  # Outcome: map of conversation_id -> %{content, sender_id, inserted_at}
  defp fetch_latest_messages(conversation_ids) when conversation_ids != [] do
    # Subquery finds the max inserted_at per conversation
    latest_times =
      from(m in MessageSchema,
        where: m.conversation_id in ^conversation_ids,
        group_by: m.conversation_id,
        select: %{conversation_id: m.conversation_id, max_at: max(m.inserted_at)}
      )

    from(m in MessageSchema,
      join: lt in subquery(latest_times),
      on: m.conversation_id == lt.conversation_id and m.inserted_at == lt.max_at,
      select: %{
        conversation_id: m.conversation_id,
        content: m.content,
        sender_id: m.sender_id,
        inserted_at: m.inserted_at
      }
    )
    |> Repo.all()
    |> Map.new(&{&1.conversation_id, &1})
  end

  defp fetch_latest_messages(_), do: %{}

  # Trigger: bootstrap needs to pre-populate system note tokens from existing system messages
  # Why: system messages with broadcast tokens must be tracked in the read table for dedup
  # Outcome: map of conversation_id -> %{token => iso8601_timestamp}
  defp fetch_system_notes(conversation_ids) when conversation_ids != [] do
    from(m in MessageSchema,
      where:
        m.conversation_id in ^conversation_ids and
          m.message_type == "system" and
          is_nil(m.deleted_at) and
          like(m.content, "%[broadcast:%"),
      select: %{
        conversation_id: m.conversation_id,
        content: m.content,
        inserted_at: m.inserted_at
      }
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn %{conversation_id: conv_id, content: content, inserted_at: at}, acc ->
      case Regex.run(@broadcast_token_regex, content || "") do
        [token] ->
          conv_notes = Map.get(acc, conv_id, %{})
          updated_notes = Map.put(conv_notes, token, DateTime.to_iso8601(at))
          Map.put(acc, conv_id, updated_notes)

        _ ->
          acc
      end
    end)
  end

  defp fetch_system_notes(_), do: %{}

  # Trigger: bootstrap needs unread counts per (conversation, participant) without loading messages
  # Why: counting in DB is far cheaper than loading all messages into memory
  # Outcome: map of {conversation_id, user_id} -> unread_count
  defp fetch_unread_counts(conversations) do
    # Build a list of {conversation_id, user_id, last_read_at} for each active participant
    participant_info =
      Enum.flat_map(conversations, fn conv ->
        conv.participants
        |> Enum.filter(&is_nil(&1.left_at))
        |> Enum.map(&{conv.id, &1.user_id, &1.last_read_at})
      end)

    # Group by last_read_at to batch queries efficiently
    # Most common case: nil (never read) or a few distinct timestamps
    {nil_readers, dated_readers} =
      Enum.split_with(participant_info, fn {_, _, lr} -> is_nil(lr) end)

    nil_counts = fetch_unread_counts_nil(nil_readers)
    dated_counts = fetch_unread_counts_dated(dated_readers)

    Map.merge(nil_counts, dated_counts)
  end

  # Trigger: participants who have never read — all messages from others are unread
  # Why: no last_read_at means every message from other senders counts
  # Outcome: count of messages per (conversation, user) where sender != user
  defp fetch_unread_counts_nil([]), do: %{}

  defp fetch_unread_counts_nil(readers) do
    # For nil last_read_at: count all messages from other senders
    Enum.reduce(readers, %{}, fn {conv_id, user_id, _}, acc ->
      count =
        from(m in MessageSchema,
          where: m.conversation_id == ^conv_id and m.sender_id != ^user_id,
          select: count(m.id)
        )
        |> Repo.one()

      Map.put(acc, {conv_id, user_id}, count)
    end)
  end

  # Trigger: participants with a last_read_at — only messages after that timestamp are unread
  # Why: messages before last_read_at have already been seen
  # Outcome: count of messages per (conversation, user) where sender != user and after last_read_at
  defp fetch_unread_counts_dated([]), do: %{}

  defp fetch_unread_counts_dated(readers) do
    Enum.reduce(readers, %{}, fn {conv_id, user_id, last_read_at}, acc ->
      count =
        from(m in MessageSchema,
          where:
            m.conversation_id == ^conv_id and
              m.sender_id != ^user_id and
              m.inserted_at > ^last_read_at,
          select: count(m.id)
        )
        |> Repo.one()

      Map.put(acc, {conv_id, user_id}, count)
    end)
  end
end
