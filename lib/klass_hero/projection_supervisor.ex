defmodule KlassHero.ProjectionSupervisor do
  @moduledoc """
  Supervises all CQRS projection GenServers under an isolated subtree.

  Uses `:one_for_one` strategy — each projection crashes and restarts
  independently. Projections that depend on others during bootstrap
  (e.g., ProgramListings → VerifiedProviders) handle unavailability
  via their own retry logic.
  """

  use Supervisor

  alias KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries
  alias KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren
  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListings
  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderPrograms
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionStats

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      VerifiedProviders,
      ProgramListings,
      EnrolledChildren,
      ConversationSummaries,
      ProviderSessionStats,
      ProviderPrograms,
      ProviderSessionDetails
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end
end
