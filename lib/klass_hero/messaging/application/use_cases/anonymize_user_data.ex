defmodule KlassHero.Messaging.Application.UseCases.AnonymizeUserData do
  @moduledoc """
  Use case for anonymizing a user's messaging data as part of GDPR deletion.

  Replaces message content with `"[deleted]"` and marks all active
  conversation participations as left. Publishes a `message_data_anonymized`
  integration event on success.

  Full GDPR-compliant anonymization of the user identity is performed by the
  Accounts context. This use case handles the Messaging context's portion of that cascade.
  """

  alias KlassHero.Messaging.IntegrationEventPublisher
  alias KlassHero.Messaging.Repositories
  alias KlassHero.Repo

  require Logger

  @doc """
  Anonymizes all messaging data for a user.

  All database operations run in a single transaction to prevent partial
  anonymization (e.g. messages anonymized but participations still active).
  The integration event is published after commit — PubSub is a side effect
  that cannot be rolled back.

  ## Parameters

  - `user_id` - The ID of the user to anonymize

  ## Returns

  - `{:ok, %{messages_anonymized: n, participants_updated: n}}` - Success
  - `{:error, reason}` - Failure at any step
  """
  @spec execute(binary()) :: {:ok, map()} | {:error, term()}
  def execute(user_id) do
    user_id
    |> run_anonymization_transaction()
    |> handle_result(user_id)
  end

  defp run_anonymization_transaction(user_id) do
    repos = Repositories.all()

    Repo.transaction(fn ->
      with {:ok, msg_count} <-
             tag_step(:anonymize_messages, repos.messages.anonymize_for_sender(user_id)),
           {:ok, part_count} <-
             tag_step(:mark_as_left, repos.participants.mark_all_as_left(user_id)) do
        %{messages_anonymized: msg_count, participants_updated: part_count}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # Passes through success, tags errors with the step name for traceability
  defp tag_step(_step, {:ok, _} = result), do: result
  defp tag_step(step, {:error, reason}), do: {:error, {step, reason}}

  defp handle_result({:ok, result}, user_id) do
    publish_integration_event(user_id)

    Logger.info("Anonymized messaging data for user",
      user_id: user_id,
      messages_anonymized: result.messages_anonymized,
      participants_updated: result.participants_updated
    )

    {:ok, result}
  end

  defp handle_result({:error, reason} = error, user_id) do
    Logger.error("Failed to anonymize messaging data for user",
      user_id: user_id,
      reason: inspect(reason)
    )

    error
  end

  defp publish_integration_event(user_id) do
    case IntegrationEventPublisher.publish_message_data_anonymized(user_id) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish message_data_anonymized event",
          user_id: user_id,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
