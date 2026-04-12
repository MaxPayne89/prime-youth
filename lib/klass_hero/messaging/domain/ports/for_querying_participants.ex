defmodule KlassHero.Messaging.Domain.Ports.ForQueryingParticipants do
  @moduledoc """
  Read-only port for querying conversation participants in the Messaging bounded context.

  Separated from `ForManagingParticipants` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Messaging.Domain.Models.Participant

  @doc """
  Gets a participant by conversation and user.

  Returns:
  - `{:ok, Participant.t()}` - Participant found
  - `{:error, :not_found}` - User is not a participant
  """
  @callback get(conversation_id :: binary(), user_id :: binary()) ::
              {:ok, Participant.t()} | {:error, :not_found}

  @doc """
  Lists all active participants for a conversation.

  Returns participants who haven't left (left_at is nil).
  """
  @callback list_for_conversation(conversation_id :: binary()) :: [Participant.t()]

  @doc """
  Checks if a user is an active participant in a conversation.
  """
  @callback is_participant?(conversation_id :: binary(), user_id :: binary()) :: boolean()
end
