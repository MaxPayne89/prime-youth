defmodule KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren do
  @moduledoc """
  Event-driven projection maintaining the `messaging_enrolled_children` lookup table.

  This GenServer subscribes to cross-context integration events from
  Enrollment and Family, plus Messaging's own `conversation_created` event.
  It maintains a local lookup of enrolled children per parent+program,
  then emits `enrolled_children_changed` domain events that the
  `ConversationSummaries` projection consumes.

  ## Event Subscriptions

  - `integration:enrollment:enrollment_created` — upserts a lookup row
  - `integration:enrollment:enrollment_cancelled` — deletes a lookup row
  - `integration:family:child_created` — updates child_first_name
  - `integration:family:child_updated` — updates child_first_name
  - `integration:messaging:conversation_created` — triggers name resolution for new conversations
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EnrolledChildrenSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @enrollment_created_topic "integration:enrollment:enrollment_created"
  @enrollment_cancelled_topic "integration:enrollment:enrollment_cancelled"
  @child_created_topic "integration:family:child_created"
  @child_updated_topic "integration:family:child_updated"
  @conversation_created_topic "integration:messaging:conversation_created"

  @enrolled_children_changed_topic "messaging:enrolled_children_changed"

  # Client API

  @doc """
  Starts the EnrolledChildren projection GenServer.

  ## Options

  - `:name` - Process name (defaults to `__MODULE__`)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Rebuilds the messaging_enrolled_children read table from the write tables.

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
    # Outcome: subscribed to all five relevant topics
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @enrollment_created_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @enrollment_cancelled_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @child_created_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @child_updated_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @conversation_created_topic)

    {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # Trigger: GenServer initialization complete
    # Why: project all existing enrollments from write tables into read table
    # Outcome: messaging_enrolled_children table populated with current data
    attempt_bootstrap(state)
  end

  # Trigger: external caller requests a full rebuild (e.g. after seeding)
  # Why: seeds insert into write tables without emitting integration events
  # Outcome: messaging_enrolled_children read table refreshed from write tables
  @impl true
  def handle_call(:rebuild, _from, state) do
    count = bootstrap_from_write_tables()
    Logger.info("EnrolledChildren rebuilt", count: count)
    {:reply, :ok, %{state | bootstrapped: true}}
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  # Trigger: Received an enrollment_created integration event
  # Why: a new enrollment was created, upsert a lookup row
  # Outcome: one row inserted/updated in messaging_enrolled_children
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :enrollment_created} = event}, state) do
    Logger.debug("EnrolledChildren projecting enrollment_created",
      enrollment_id: event.entity_id
    )

    project_enrollment_created(event)
    {:noreply, state}
  end

  # Trigger: Received an enrollment_cancelled integration event
  # Why: enrollment cancelled, remove the lookup row
  # Outcome: row deleted from messaging_enrolled_children
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :enrollment_cancelled} = event}, state) do
    Logger.debug("EnrolledChildren projecting enrollment_cancelled",
      enrollment_id: event.entity_id
    )

    project_enrollment_cancelled(event)
    {:noreply, state}
  end

  # Trigger: Received a child_created integration event
  # Why: new child may need first_name populated in existing lookup rows
  # Outcome: child_first_name updated for matching rows
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :child_created} = event}, state) do
    Logger.debug("EnrolledChildren projecting child_created", child_id: event.entity_id)
    project_child_name_change(event)
    {:noreply, state}
  end

  # Trigger: Received a child_updated integration event
  # Why: child name may have changed, update lookup rows
  # Outcome: child_first_name updated for matching rows
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :child_updated} = event}, state) do
    Logger.debug("EnrolledChildren projecting child_updated", child_id: event.entity_id)
    project_child_name_change(event)
    {:noreply, state}
  end

  # Trigger: Received a conversation_created integration event
  # Why: new conversation may need child names resolved for its participants
  # Outcome: enrolled_children_changed emitted if any participant has enrolled children
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :conversation_created} = event}, state) do
    project_conversation_created(event)
    {:noreply, state}
  end

  # Catch-all for unhandled messages — logged so misrouted events are traceable
  @impl true
  def handle_info(msg, state) do
    Logger.warning("EnrolledChildren received unexpected message",
      message: inspect(msg, limit: 200)
    )

    {:noreply, state}
  end

  # Private — Bootstrap

  # Trigger: bootstrap attempt with retry logic
  # Why: transient DB failures shouldn't crash the GenServer immediately
  # Outcome: successful bootstrap or scheduled retry (up to 3 times before crashing)
  defp attempt_bootstrap(state) do
    count = bootstrap_from_write_tables()
    Logger.info("EnrolledChildren projection started", count: count)
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
        Logger.error("EnrolledChildren: bootstrap failed, scheduling retry",
          error: Exception.message(error),
          retry_count: retry_count
        )

        Process.send_after(self(), :retry_bootstrap, 5_000 * retry_count)
        {:noreply, Map.put(state, :retry_count, retry_count)}
      end
  end

  # Trigger: bootstrap phase — read table may be empty or stale
  # Why: cold start recovery — populate read table from authoritative write tables
  # Outcome: messaging_enrolled_children contains one row per (parent_user, program, child)
  defp bootstrap_from_write_tables do
    entries =
      from(e in "enrollments",
        join: c in "children",
        on: c.id == e.child_id,
        join: pp in "parents",
        on: pp.id == e.parent_id,
        where: e.status in ["pending", "confirmed"],
        select: %{
          parent_user_id: type(pp.identity_id, :binary_id),
          program_id: type(e.program_id, :binary_id),
          child_id: type(e.child_id, :binary_id),
          child_first_name: c.first_name
        }
      )
      |> Repo.all()

    if entries == [] do
      0
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      rows =
        Enum.map(entries, fn entry ->
          Map.merge(entry, %{id: Ecto.UUID.generate(), inserted_at: now, updated_at: now})
        end)

      {count, _} =
        Repo.insert_all(EnrolledChildrenSchema, rows,
          on_conflict: {:replace, [:child_first_name, :updated_at]},
          conflict_target: [:parent_user_id, :program_id, :child_id]
        )

      count
    end
  end

  # Private — Event Projections

  # Trigger: enrollment_created event received
  # Why: a new enrollment needs a lookup row so child names can be resolved
  # Outcome: one row upserted, then re-derivation emits enrolled_children_changed
  defp project_enrollment_created(event) do
    payload = event.payload
    parent_user_id = payload.parent_user_id
    program_id = payload.program_id
    child_id = payload.child_id
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %EnrolledChildrenSchema{}
    |> Ecto.Changeset.change(%{
      id: Ecto.UUID.generate(),
      parent_user_id: parent_user_id,
      program_id: program_id,
      child_id: child_id,
      child_first_name: nil,
      inserted_at: now,
      updated_at: now
    })
    |> Repo.insert!(
      on_conflict: {:replace, [:updated_at]},
      conflict_target: [:parent_user_id, :program_id, :child_id]
    )

    re_derive_and_emit(parent_user_id, program_id)
  end

  # Trigger: enrollment_cancelled event received
  # Why: cancelled enrollments should not appear in child name lists
  # Outcome: row deleted, then re-derivation emits enrolled_children_changed
  #
  # Special: the event doesn't carry parent_user_id, so we look it up from
  # the existing row before deleting it
  defp project_enrollment_cancelled(event) do
    payload = event.payload
    child_id = payload.child_id
    program_id = payload.program_id

    parent_user_id =
      from(e in EnrolledChildrenSchema,
        where: e.child_id == ^child_id and e.program_id == ^program_id,
        select: e.parent_user_id,
        limit: 1
      )
      |> Repo.one()

    if parent_user_id do
      from(e in EnrolledChildrenSchema,
        where: e.child_id == ^child_id and e.program_id == ^program_id
      )
      |> Repo.delete_all()

      re_derive_and_emit(parent_user_id, program_id)
    end
  end

  # Trigger: child_created or child_updated event received
  # Why: child's first_name may have changed, update all matching lookup rows
  # Outcome: child_first_name updated, then re-derivation for each affected (parent, program)
  defp project_child_name_change(event) do
    payload = event.payload
    child_id = payload.child_id
    first_name = payload.first_name
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    affected =
      from(e in EnrolledChildrenSchema,
        where: e.child_id == ^child_id,
        select: {e.parent_user_id, e.program_id}
      )
      |> Repo.all()

    if affected != [] do
      from(e in EnrolledChildrenSchema, where: e.child_id == ^child_id)
      |> Repo.update_all(set: [child_first_name: first_name, updated_at: now])

      affected
      |> Enum.uniq()
      |> Enum.each(fn {parent_user_id, program_id} ->
        re_derive_and_emit(parent_user_id, program_id)
      end)
    end
  end

  # Trigger: conversation_created event received
  # Why: new conversations need child names resolved for their participants
  # Outcome: enrolled_children_changed emitted for each participant with enrolled children
  #
  # Special: uses event payload directly for conversation_id and participant_ids
  # because the ConversationSummaries row may not exist yet
  defp project_conversation_created(event) do
    payload = event.payload
    program_id = Map.get(payload, :program_id)
    conversation_type = payload |> Map.get(:type, "direct") |> to_string()

    if conversation_type == "direct" and program_id do
      participant_ids = Map.get(payload, :participant_ids, [])
      conversation_id = payload.conversation_id

      Enum.each(participant_ids, fn user_id ->
        child_names = get_child_names(user_id, program_id)

        if child_names != [] do
          emit_enrolled_children_changed(conversation_id, child_names)
        end
      end)
    end
  end

  # Private — Re-derivation

  # Trigger: a row in messaging_enrolled_children was added, removed, or updated
  # Why: downstream consumers (ConversationSummaries) need the updated child name list
  # Outcome: enrolled_children_changed domain event emitted for each affected conversation
  defp re_derive_and_emit(parent_user_id, program_id) do
    conversation_ids =
      from(s in ConversationSummarySchema,
        where:
          s.user_id == ^parent_user_id and
            s.program_id == ^program_id and
            s.conversation_type == "direct",
        select: s.conversation_id,
        distinct: true
      )
      |> Repo.all()

    if conversation_ids != [] do
      child_names = get_child_names(parent_user_id, program_id)

      Enum.each(conversation_ids, fn conversation_id ->
        emit_enrolled_children_changed(conversation_id, child_names)
      end)
    end
  end

  # Trigger: need sorted child names for a (parent_user, program) pair
  # Why: child names are displayed alphabetically, nil names excluded
  # Outcome: list of non-nil first names, sorted alphabetically
  defp get_child_names(parent_user_id, program_id) do
    from(e in EnrolledChildrenSchema,
      where:
        e.parent_user_id == ^parent_user_id and
          e.program_id == ^program_id and
          not is_nil(e.child_first_name),
      select: e.child_first_name,
      order_by: e.child_first_name
    )
    |> Repo.all()
  end

  # Trigger: child names resolved for a conversation
  # Why: ConversationSummaries projection listens for this event to update its read table
  # Outcome: domain event broadcast on PubSub
  defp emit_enrolled_children_changed(conversation_id, child_names) do
    event =
      DomainEvent.new(
        :enrolled_children_changed,
        conversation_id,
        :conversation,
        %{
          conversation_id: conversation_id,
          enrolled_child_names: child_names
        }
      )

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      @enrolled_children_changed_topic,
      {:domain_event, event}
    )
  end
end
