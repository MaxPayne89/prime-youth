defmodule KlassHero.ProjectionSupervisor do
  @moduledoc """
  Supervises all CQRS projection GenServers under an isolated subtree.

  Uses `:rest_for_one` strategy because ProgramListings depends on
  VerifiedProviders during bootstrap (calls `VerifiedProviders.verified?/1`).
  If VerifiedProviders crashes, ProgramListings must also restart to
  re-bootstrap with correct verification data.

  Isolated supervision prevents projection crashes from taking down
  infrastructure children (Repo, PubSub, Endpoint) in the top-level supervisor.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Trigger: VerifiedProviders must start before ProgramListings
      # Why: ProgramListings.bootstrap calls VerifiedProviders.verified?/1
      # Outcome: rest_for_one ensures ProgramListings restarts if VerifiedProviders crashes
      KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders,
      KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListings,
      KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries
    ]

    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 10, max_seconds: 60)
  end
end
