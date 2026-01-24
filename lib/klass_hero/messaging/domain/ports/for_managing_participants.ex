defmodule KlassHero.Messaging.Domain.Ports.ForManagingParticipants do
  @moduledoc """
  Repository port for managing conversation participants in the Messaging bounded context.

  This behaviour defines the contract for participant persistence.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.Messaging.Domain.Models.Participant

  @doc """
  Adds a participant to a conversation.

  Returns:
  - `{:ok, Participant.t()}` - Participant added
  - `{:error, :already_participant}` - User already in conversation
  - `{:error, changeset}` - Validation failure
  """
  @callback add(attrs :: map()) ::
              {:ok, Participant.t()} | {:error, :already_participant | term()}

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
  Updates the last_read_at timestamp for a participant.

  Returns:
  - `{:ok, Participant.t()}` - Updated successfully
  - `{:error, :not_found}` - Participant not found
  """
  @callback mark_as_read(
              conversation_id :: binary(),
              user_id :: binary(),
              read_at :: DateTime.t()
            ) ::
              {:ok, Participant.t()} | {:error, :not_found}

  @doc """
  Removes a participant from a conversation.

  Sets left_at timestamp rather than deleting.
  """
  @callback leave(conversation_id :: binary(), user_id :: binary()) ::
              {:ok, Participant.t()} | {:error, :not_found}

  @doc """
  Checks if a user is an active participant in a conversation.
  """
  @callback is_participant?(conversation_id :: binary(), user_id :: binary()) :: boolean()

  @doc """
  Adds multiple participants to a conversation in a batch.

  Used for program broadcasts to add all enrolled parents.
  """
  @callback add_batch(conversation_id :: binary(), user_ids :: [binary()]) ::
              {:ok, [Participant.t()]}
end
