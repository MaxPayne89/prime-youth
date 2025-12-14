defmodule PrimeYouth.Providing.Adapters.Driven.Events.IdentityEventHandler do
  @moduledoc """
  Event handler for Identity (Accounts) events that affect the Providing context.

  This handler listens to user-related events from the Accounts context and
  automatically creates Provider profiles when users register with the "provider" role.

  ## Subscribed Events

  - `:user_registered` - Auto-creates Provider profile if "provider" in intended_roles

  ## Profile Creation

  When creating Provider profiles:
  - `business_name` defaults to user's name (can be updated later)
  - `identity_id` is set to the user's ID for correlation

  ## Error Handling

  Profile creation errors are handled gracefully with retry logic:
  - Duplicate identity → :ok (profile already exists)
  - Transient errors → Retry once, then log error
  - All errors are logged but don't block event processing
  """

  @behaviour PrimeYouth.Shared.Domain.Ports.ForHandlingEvents

  alias PrimeYouth.Providing

  require Logger

  @impl true
  def subscribed_events, do: [:user_registered]

  @impl true
  def handle_event(%{event_type: :user_registered, aggregate_id: user_id, payload: payload}) do
    intended_roles = Map.get(payload, :intended_roles, [])

    if "provider" in intended_roles do
      # Use user's name as default business_name
      business_name = Map.get(payload, :name, "")
      create_provider_profile_with_retry(user_id, business_name)
    else
      :ignore
    end
  end

  def handle_event(_event), do: :ignore

  # Private functions

  defp create_provider_profile_with_retry(user_id, business_name) do
    attrs = %{
      identity_id: user_id,
      business_name: business_name
    }

    case Providing.create_provider_profile(attrs) do
      {:ok, _provider} ->
        Logger.info(
          "Successfully created provider profile for user #{user_id} with business_name: #{business_name}"
        )

        :ok

      {:error, :duplicate_identity} ->
        Logger.debug("Provider profile already exists for user #{user_id}")
        :ok

      {:error, reason} = error ->
        Logger.warning(
          "First attempt to create provider profile failed: #{inspect(reason)}, retrying..."
        )

        # Retry once
        case Providing.create_provider_profile(attrs) do
          {:ok, _provider} ->
            Logger.info(
              "Successfully created provider profile for user #{user_id} on retry with business_name: #{business_name}"
            )

            :ok

          {:error, :duplicate_identity} ->
            Logger.debug("Provider profile already exists for user #{user_id}")
            :ok

          {:error, retry_reason} ->
            Logger.error(
              "Failed to create provider profile for user #{user_id} after retry: #{inspect(retry_reason)}"
            )

            error
        end
    end
  end
end
