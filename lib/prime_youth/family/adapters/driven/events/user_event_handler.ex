defmodule PrimeYouth.Family.Adapters.Driven.Events.UserEventHandler do
  @moduledoc """
  Handles user lifecycle events for the Family context.

  This handler demonstrates cross-context event communication by
  subscribing to events from the Accounts context.

  ## Subscribed Events

  - `:user_registered` - When a new user registers, can initialize family profile
  - `:user_confirmed` - When user confirms email, can activate family features
  """

  @behaviour PrimeYouth.Shared.Domain.Ports.ForHandlingEvents

  require Logger

  @impl true
  def subscribed_events, do: [:user_registered, :user_confirmed]

  @impl true
  def handle_event(%{event_type: :user_registered} = event) do
    Logger.info("Family context received user_registered event for user #{event.aggregate_id}")
    :ok
  end

  def handle_event(%{event_type: :user_confirmed} = event) do
    Logger.info("Family context received user_confirmed event for user #{event.aggregate_id}")
    :ok
  end

  def handle_event(_event), do: :ignore
end
