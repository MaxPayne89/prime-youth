defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails do
  @moduledoc """
  Event-driven projection maintaining `provider_session_details`.

  Subscribes to Participation session/attendance events and Provider staff events.
  Self-heals on every boot by replaying the bootstrap query into the read table.
  """

  use GenServer

  @session_created_topic "integration:participation:session_created"
  @session_started_topic "integration:participation:session_started"
  @session_completed_topic "integration:participation:session_completed"
  @session_cancelled_topic "integration:participation:session_cancelled"
  @roster_seeded_topic "integration:participation:roster_seeded"
  @child_checked_in_topic "integration:participation:child_checked_in"
  @child_checked_out_topic "integration:participation:child_checked_out"
  @child_marked_absent_topic "integration:participation:child_marked_absent"
  @staff_assigned_topic "integration:provider:staff_assigned_to_program"
  @staff_unassigned_topic "integration:provider:staff_unassigned_from_program"

  @topics [
    @session_created_topic,
    @session_started_topic,
    @session_completed_topic,
    @session_cancelled_topic,
    @roster_seeded_topic,
    @child_checked_in_topic,
    @child_checked_out_topic,
    @child_marked_absent_topic,
    @staff_assigned_topic,
    @staff_unassigned_topic
  ]

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Rebuilds the read table from write models. Useful after seeds."
  def rebuild(name \\ __MODULE__), do: GenServer.call(name, :rebuild, :infinity)

  @impl true
  def init(_opts) do
    Enum.each(@topics, &Phoenix.PubSub.subscribe(KlassHero.PubSub, &1))
    {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # implementation comes in Task 13
    {:noreply, %{state | bootstrapped: true}}
  end

  @impl true
  def handle_call(:rebuild, _from, state) do
    # implementation comes in Task 13
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  @impl true
  def handle_info({:integration_event, _event}, state) do
    # event clauses come in Tasks 8–12
    {:noreply, state}
  end
end
