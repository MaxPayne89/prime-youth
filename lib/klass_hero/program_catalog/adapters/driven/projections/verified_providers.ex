defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders do
  @moduledoc """
  In-memory projection of verified provider IDs.

  This GenServer maintains a MapSet of provider IDs that are verified, enabling
  fast O(1) lookups without database queries. It bootstraps from the Identity
  context on startup and stays in sync via integration events.

  ## Architecture

  This is a "driven adapter" in the Ports & Adapters architecture - it's driven
  by integration events from the Identity context. The Program Catalog context
  uses this projection to enrich program data with provider verification status.

  ## Startup Behavior

  On init, the GenServer:
  1. Subscribes to `integration:identity:provider_verified` topic
  2. Subscribes to `integration:identity:provider_unverified` topic
  3. Calls `Identity.list_verified_provider_ids/0` to bootstrap the MapSet

  ## Event Handling

  - `:provider_verified` events add the provider ID to the MapSet
  - `:provider_unverified` events remove the provider ID from the MapSet
  """

  use GenServer

  alias KlassHero.Identity
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @verified_topic "integration:identity:provider_verified"
  @unverified_topic "integration:identity:provider_unverified"

  # Client API

  @doc """
  Starts the VerifiedProviders GenServer.

  ## Options

  - `:name` - Process name (defaults to `__MODULE__`)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checks if a provider is verified.

  Returns `true` if the provider ID is in the verified set, `false` otherwise.

  ## Parameters

  - `provider_id` - The UUID of the provider profile to check
  - `name` - The GenServer name (defaults to `__MODULE__`)

  ## Examples

      iex> VerifiedProviders.verified?("some-uuid")
      true

      iex> VerifiedProviders.verified?("unknown-uuid")
      false
  """
  @spec verified?(String.t(), GenServer.name()) :: boolean()
  def verified?(provider_id, name \\ __MODULE__) do
    GenServer.call(name, {:verified?, provider_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Trigger: GenServer is starting
    # Why: Need to subscribe to events before bootstrapping to avoid missing events
    # Outcome: Subscribed to both verified and unverified topics
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @verified_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @unverified_topic)

    # Use handle_continue to bootstrap after init completes
    # This ensures the GenServer is fully initialized before any blocking calls
    {:ok, %{verified_ids: MapSet.new()}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # Trigger: GenServer initialization complete
    # Why: Bootstrap from Identity context to hydrate in-memory cache
    # Outcome: MapSet populated with all currently verified provider IDs
    verified_ids = bootstrap_verified_ids()

    Logger.info("VerifiedProviders projection started",
      count: MapSet.size(verified_ids)
    )

    {:noreply, %{state | verified_ids: verified_ids}}
  end

  @impl true
  def handle_call({:verified?, provider_id}, _from, state) do
    result = MapSet.member?(state.verified_ids, provider_id)
    {:reply, result, state}
  end

  # Trigger: Received a provider_verified integration event
  # Why: Identity context notifies other contexts when a provider is verified
  # Outcome: Provider ID added to the in-memory MapSet
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :provider_verified} = event},
        state
      ) do
    provider_id = event.payload.provider_id

    Logger.debug("Provider verified in projection",
      provider_id: provider_id,
      event_id: event.event_id
    )

    new_ids = MapSet.put(state.verified_ids, provider_id)
    {:noreply, %{state | verified_ids: new_ids}}
  end

  # Trigger: Received a provider_unverified integration event
  # Why: Identity context notifies other contexts when a provider loses verification
  # Outcome: Provider ID removed from the in-memory MapSet
  @impl true
  def handle_info(
        {:integration_event, %IntegrationEvent{event_type: :provider_unverified} = event},
        state
      ) do
    provider_id = event.payload.provider_id

    Logger.debug("Provider unverified in projection",
      provider_id: provider_id,
      event_id: event.event_id
    )

    new_ids = MapSet.delete(state.verified_ids, provider_id)
    {:noreply, %{state | verified_ids: new_ids}}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Trigger: GenServer needs initial state from Identity context
  # Why: Cold start recovery - populate cache from authoritative source
  # Outcome: Returns MapSet of verified provider IDs, or empty set on failure
  defp bootstrap_verified_ids do
    case Identity.list_verified_provider_ids() do
      {:ok, ids} ->
        MapSet.new(ids)

      {:error, reason} ->
        Logger.warning("Failed to bootstrap verified providers",
          error: inspect(reason)
        )

        MapSet.new()
    end
  end
end
