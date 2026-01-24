defmodule KlassHero.Messaging.Application.UseCases.GetConversation do
  @moduledoc """
  Use case for retrieving a conversation with messages.

  This use case:
  1. Retrieves the conversation by ID
  2. Verifies the requester is a participant
  3. Loads messages with pagination
  4. Optionally marks messages as read
  5. Returns conversation with messages enriched with sender names
  """

  alias KlassHero.Messaging.Application.UseCases.MarkAsRead

  require Logger

  @doc """
  Gets a conversation with its messages.

  ## Parameters
  - conversation_id: The conversation to retrieve
  - user_id: The requesting user (for access control)
  - opts: Optional parameters
    - limit: Number of messages to return (default 50)
    - before: Get messages before this timestamp
    - mark_as_read: Whether to mark messages as read (default false)

  ## Returns
  - `{:ok, result_map}` - Success, with:
    - `:conversation` - The conversation entity
    - `:messages` - List of messages with sender_name enriched
    - `:has_more` - Whether there are more messages
    - `:sender_names` - Map of sender_id => display name
  - `{:error, :not_found}` - Conversation doesn't exist
  - `{:error, :not_participant}` - User is not in the conversation
  """
  @spec execute(String.t(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error, :not_found | :not_participant}
  def execute(conversation_id, user_id, opts \\ []) do
    conversation_repo = conversation_repository()
    message_repo = message_repository()
    participant_repo = participant_repository()
    mark_as_read? = Keyword.get(opts, :mark_as_read, false)

    with {:ok, conversation} <-
           conversation_repo.get_by_id(conversation_id, preload: [:participants]),
         :ok <- verify_participant(conversation_id, user_id, participant_repo),
         {:ok, messages, sender_names, has_more} <-
           message_repo.list_with_senders(conversation_id, opts) do
      if mark_as_read?, do: MarkAsRead.execute(conversation_id, user_id)

      Logger.debug("Retrieved conversation",
        conversation_id: conversation_id,
        user_id: user_id,
        message_count: length(messages)
      )

      {:ok,
       %{
         conversation: conversation,
         messages: messages,
         has_more: has_more,
         sender_names: sender_names
       }}
    end
  end

  defp verify_participant(conversation_id, user_id, participant_repo) do
    if participant_repo.is_participant?(conversation_id, user_id) do
      :ok
    else
      {:error, :not_participant}
    end
  end

  defp conversation_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_conversations]
  end

  defp message_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_messages]
  end

  defp participant_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_participants]
  end
end
