defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListings do
  @moduledoc """
  Event-driven projection maintaining the `program_listings` read table.

  This GenServer subscribes to integration events and keeps the denormalized
  `program_listings` table in sync with the write model. On startup it
  bootstraps from the `programs` write table, then incrementally applies
  changes as events arrive.

  ## Architecture

  This is a "driven adapter" in the Ports & Adapters architecture — it's driven
  by integration events from ProgramCatalog and Provider contexts. The read-side
  repository (`ProgramListingsRepository`) queries the table this projection writes.

  ## Startup Behavior

  On init, the GenServer:
  1. Subscribes to program_created, program_updated, provider_verified, provider_unverified topics
  2. Uses `handle_continue(:bootstrap)` to project all existing programs into the read table

  ## Event Handling

  - `:program_created` — inserts a new row into program_listings
  - `:program_updated` — updates the existing row with changed fields
  - `:provider_verified` — sets `provider_verified = true` for all listings of that provider
  - `:provider_unverified` — sets `provider_verified = false` for all listings of that provider
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @program_created_topic "integration:program_catalog:program_created"
  @program_updated_topic "integration:program_catalog:program_updated"
  @provider_verified_topic "integration:provider:provider_verified"
  @provider_unverified_topic "integration:provider:provider_unverified"

  # Fields shared between ProgramSchema and ProgramListingSchema
  @shared_fields [
    :title,
    :description,
    :category,
    :age_range,
    :price,
    :pricing_period,
    :location,
    :cover_image_url,
    :instructor_name,
    :instructor_headshot_url,
    :start_date,
    :end_date,
    :meeting_days,
    :meeting_start_time,
    :meeting_end_time,
    :season,
    :registration_start_date,
    :registration_end_date,
    :provider_id
  ]

  # Client API

  @doc """
  Starts the ProgramListings projection GenServer.

  ## Options

  - `:name` - Process name (defaults to `__MODULE__`)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Rebuilds the program_listings read table from the programs write table.

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
    # Outcome: subscribed to all four relevant topics
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @program_created_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @program_updated_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @provider_verified_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @provider_unverified_topic)

    {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # Trigger: GenServer initialization complete
    # Why: project all existing programs from write table into read table
    # Outcome: program_listings table populated with current program data
    attempt_bootstrap(state)
  end

  # Trigger: external caller requests a full rebuild (e.g. after seeding)
  # Why: seeds insert into write tables without emitting integration events
  # Outcome: program_listings read table refreshed from programs write table
  @impl true
  def handle_call(:rebuild, _from, state) do
    count = bootstrap_from_write_table()
    Logger.info("ProgramListings rebuilt", count: count)
    {:reply, :ok, %{state | bootstrapped: true}}
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  # Trigger: Received a program_created integration event
  # Why: a new program was created in the write model, the read table needs a corresponding row
  # Outcome: new row inserted into program_listings
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :program_created} = event}, state) do
    Logger.debug("ProgramListings projecting program_created",
      program_id: event.entity_id,
      event_id: event.event_id
    )

    upsert_listing_from_event(event)
    {:noreply, state}
  end

  # Trigger: Received a program_updated integration event
  # Why: program fields changed in the write model, the read table must reflect them
  # Outcome: existing row in program_listings updated with new field values
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :program_updated} = event}, state) do
    Logger.debug("ProgramListings projecting program_updated",
      program_id: event.entity_id,
      event_id: event.event_id
    )

    update_listing_from_event(event)
    {:noreply, state}
  end

  # Trigger: Received a provider_verified integration event
  # Why: provider gained verification status, all their listings should reflect this
  # Outcome: provider_verified set to true for all listings belonging to that provider
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :provider_verified} = event}, state) do
    provider_id = event.payload.provider_id

    Logger.debug("ProgramListings setting provider_verified=true",
      provider_id: provider_id,
      event_id: event.event_id
    )

    set_provider_verification(provider_id, true)
    {:noreply, state}
  end

  # Trigger: Received a provider_unverified integration event
  # Why: provider lost verification status, all their listings should reflect this
  # Outcome: provider_verified set to false for all listings belonging to that provider
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :provider_unverified} = event}, state) do
    provider_id = event.payload.provider_id

    Logger.debug("ProgramListings setting provider_verified=false",
      provider_id: provider_id,
      event_id: event.event_id
    )

    set_provider_verification(provider_id, false)
    {:noreply, state}
  end

  # Catch-all for unhandled messages — logged so misrouted events are traceable
  @impl true
  def handle_info(msg, state) do
    Logger.warning("ProgramListings received unexpected message",
      message: inspect(msg, limit: 200)
    )

    {:noreply, state}
  end

  # Private Functions

  # Trigger: bootstrap attempt with retry logic
  # Why: transient DB failures shouldn't crash the GenServer immediately
  # Outcome: successful bootstrap or scheduled retry (up to 3 times before crashing)
  defp attempt_bootstrap(state) do
    count = bootstrap_from_write_table()
    Logger.info("ProgramListings projection started", count: count)
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
        Logger.error("ProgramListings: bootstrap failed, scheduling retry",
          error: Exception.message(error),
          retry_count: retry_count
        )

        Process.send_after(self(), :retry_bootstrap, 5_000 * retry_count)
        {:noreply, Map.put(state, :retry_count, retry_count)}
      end
  end

  # Trigger: bootstrap phase — read table may be empty or stale
  # Why: cold start recovery — populate read table from authoritative write table
  # Outcome: program_listings contains one row per program with correct provider_verified status
  defp bootstrap_from_write_table do
    programs = Repo.all(ProgramSchema)

    if programs == [] do
      0
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        Enum.map(programs, fn program ->
          program
          |> Map.take(@shared_fields)
          |> Map.put(:id, program.id)
          |> Map.put(:provider_verified, lookup_provider_verified(program.provider_id))
          |> Map.put(:inserted_at, program.inserted_at || now)
          |> Map.put(:updated_at, program.updated_at || now)
        end)

      # Trigger: programs may already have rows in program_listings from a previous run
      # Why: upsert avoids duplicate key errors while keeping data fresh
      # Outcome: all programs projected, preserving original inserted_at on conflicts
      {count, _} =
        Repo.insert_all(ProgramListingSchema, entries,
          on_conflict: {:replace_all_except, [:id, :inserted_at]},
          conflict_target: :id
        )

      count
    end
  end

  # NOTE: Event handlers use bang functions (Repo.insert!, Repo.update!) intentionally.
  # If a DB write fails, the GenServer crashes and the supervisor restarts it,
  # triggering a full re-bootstrap from the write table. This is the correct recovery
  # strategy for a projection — transient failures resolve via restart, and persistent
  # failures surface as repeated crashes (hitting max_restarts).

  # Note: :icon_path was removed from this projection's schema. Stale events from before
  # this change/deploy may carry :icon_path in their payload — it is intentionally
  # discarded. Icon resolution is now handled by ProgramPresenter.icon_name/1
  # at render time using the :category field.

  # Trigger: program_created event received
  # Why: new program needs a listing row; uses upsert for idempotency
  # Outcome: row inserted (or replaced if duplicate event)
  defp upsert_listing_from_event(event) do
    payload = event.payload

    attrs = %{
      id: event.entity_id,
      title: Map.get(payload, :title),
      description: Map.get(payload, :description),
      category: Map.get(payload, :category),
      age_range: Map.get(payload, :age_range),
      price: Map.get(payload, :price),
      pricing_period: Map.get(payload, :pricing_period),
      location: Map.get(payload, :location),
      cover_image_url: Map.get(payload, :cover_image_url),
      instructor_name: extract_instructor_name(payload),
      instructor_headshot_url: extract_instructor_headshot_url(payload),
      start_date: Map.get(payload, :start_date),
      end_date: Map.get(payload, :end_date),
      meeting_days: Map.get(payload, :meeting_days, []),
      meeting_start_time: Map.get(payload, :meeting_start_time),
      meeting_end_time: Map.get(payload, :meeting_end_time),
      season: Map.get(payload, :season),
      registration_start_date: Map.get(payload, :registration_start_date),
      registration_end_date: Map.get(payload, :registration_end_date),
      provider_id: Map.get(payload, :provider_id),
      provider_verified: false
    }

    %ProgramListingSchema{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :id
    )
  end

  # Fields that program_updated events may change; excludes season and provider_verified
  # which are only set during bootstrap or by provider verification events respectively.
  @update_fields [
    :title,
    :description,
    :category,
    :age_range,
    :price,
    :pricing_period,
    :location,
    :cover_image_url,
    :instructor_name,
    :instructor_headshot_url,
    :start_date,
    :end_date,
    :meeting_days,
    :meeting_start_time,
    :meeting_end_time,
    :registration_start_date,
    :registration_end_date,
    :provider_id,
    :updated_at
  ]

  # Trigger: program_updated event received
  # Why: upsert instead of get-then-update so events for listings missing from the read
  #      table (race with bootstrap) still project instead of being silently dropped.
  #      season and provider_verified are NOT in @update_fields — on conflict they are
  #      preserved; on fresh insert they default to nil/false (next bootstrap corrects).
  # Outcome: listing row updated or inserted with event data
  defp update_listing_from_event(event) do
    program_id = event.entity_id
    payload = event.payload

    attrs = %{
      id: program_id,
      title: Map.get(payload, :title),
      description: Map.get(payload, :description),
      category: Map.get(payload, :category),
      age_range: Map.get(payload, :age_range),
      price: Map.get(payload, :price),
      pricing_period: Map.get(payload, :pricing_period),
      location: Map.get(payload, :location),
      cover_image_url: Map.get(payload, :cover_image_url),
      instructor_name: extract_instructor_name(payload),
      instructor_headshot_url: extract_instructor_headshot_url(payload),
      start_date: Map.get(payload, :start_date),
      end_date: Map.get(payload, :end_date),
      meeting_days: Map.get(payload, :meeting_days, []),
      meeting_start_time: Map.get(payload, :meeting_start_time),
      meeting_end_time: Map.get(payload, :meeting_end_time),
      registration_start_date: Map.get(payload, :registration_start_date),
      registration_end_date: Map.get(payload, :registration_end_date),
      provider_id: Map.get(payload, :provider_id),
      provider_verified: false,
      season: nil
    }

    %ProgramListingSchema{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!(
      on_conflict: {:replace, @update_fields},
      conflict_target: :id
    )
  end

  # Trigger: provider verification status changed
  # Why: all listings for this provider need their provider_verified flag updated
  # Outcome: bulk update of provider_verified for all matching rows
  defp set_provider_verification(provider_id, verified) do
    from(pl in ProgramListingSchema, where: pl.provider_id == ^provider_id)
    |> Repo.update_all(
      set: [
        provider_verified: verified,
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      ]
    )
  end

  # Trigger: bootstrap needs to know if a provider is currently verified
  # Why: VerifiedProviders projection starts before ProgramListings in the supervision tree,
  #      so it should be available. If not (e.g., test env), default to false.
  # Outcome: returns true/false based on VerifiedProviders state, or false if unavailable
  defp lookup_provider_verified(provider_id) do
    VerifiedProviders.verified?(provider_id)
  catch
    :exit, reason ->
      Logger.warning("ProgramListings: VerifiedProviders unavailable, defaulting to unverified",
        provider_id: provider_id,
        reason: inspect(reason)
      )

      false
  end

  # Trigger: payload may have instructor data in nested or flat format
  # Why: program_created has flat fields, program_updated has nested instructor map
  # Outcome: extract instructor name from whichever format is present
  defp extract_instructor_name(payload) do
    case Map.get(payload, :instructor) do
      %{name: name} -> name
      nil -> Map.get(payload, :instructor_name)
      _ -> nil
    end
  end

  # Trigger: same as extract_instructor_name but for headshot URL
  # Why: consistent extraction logic for both instructor fields
  # Outcome: extract instructor headshot URL from whichever format is present
  defp extract_instructor_headshot_url(payload) do
    case Map.get(payload, :instructor) do
      %{headshot_url: url} -> url
      nil -> Map.get(payload, :instructor_headshot_url)
      _ -> nil
    end
  end
end
