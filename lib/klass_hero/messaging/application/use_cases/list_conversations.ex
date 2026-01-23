defmodule KlassHero.Messaging.Application.UseCases.ListConversations do
  @moduledoc """
  Use case for listing a user's conversations.

  Returns conversations ordered by most recent message,
  with unread message counts for each conversation.
  """

  require Logger

  @doc """
  Lists conversations for a user.

  ## Parameters
  - user_id: The user to list conversations for
  - opts: Optional parameters
    - limit: Number of conversations to return (default 50)
    - cursor: Pagination cursor

  ## Returns
  - `{:ok, conversations, has_more}` - List of conversations with unread counts

  Each conversation map includes:
  - `:conversation` - The conversation entity
  - `:unread_count` - Number of unread messages
  - `:latest_message` - The most recent message
  - `:last_read_at` - When user last read
  - `:other_participant_name` - Display name of other participant (for direct) or subject (for broadcast)
  """
  @spec execute(String.t(), keyword()) ::
          {:ok, [map()], boolean()}
  def execute(user_id, opts \\ []) do
    conversation_repo = conversation_repository()
    message_repo = message_repository()
    participant_repo = participant_repository()
    user_resolver = user_resolver()

    {:ok, conversations, has_more} = conversation_repo.list_for_user(user_id, opts)

    other_user_ids = collect_other_participant_ids(conversations, user_id)
    {:ok, user_names} = user_resolver.get_display_names(other_user_ids)

    enriched_conversations =
      Enum.map(conversations, fn conversation ->
        enrich_conversation(conversation, user_id, user_names, message_repo, participant_repo)
      end)

    Logger.debug("Listed conversations",
      user_id: user_id,
      count: length(enriched_conversations)
    )

    {:ok, enriched_conversations, has_more}
  end

  defp collect_other_participant_ids(conversations, current_user_id) do
    conversations
    |> Enum.flat_map(fn conversation ->
      conversation.participants
      |> Enum.map(& &1.user_id)
      |> Enum.reject(&(&1 == current_user_id))
    end)
    |> Enum.uniq()
  end

  defp enrich_conversation(conversation, user_id, user_names, message_repo, participant_repo) do
    {:ok, participant} = participant_repo.get(conversation.id, user_id)
    unread_count = message_repo.count_unread(conversation.id, participant.last_read_at)

    latest_message =
      case message_repo.get_latest(conversation.id) do
        {:ok, message} -> message
        {:error, :not_found} -> nil
      end

    other_participant_name = get_other_participant_name(conversation, user_id, user_names)

    %{
      conversation: conversation,
      unread_count: unread_count,
      latest_message: latest_message,
      last_read_at: participant.last_read_at,
      other_participant_name: other_participant_name
    }
  end

  defp get_other_participant_name(
         %{type: :program_broadcast, subject: subject},
         _user_id,
         _user_names
       )
       when not is_nil(subject) do
    subject
  end

  defp get_other_participant_name(%{type: :program_broadcast}, _user_id, _user_names) do
    "Program Broadcast"
  end

  defp get_other_participant_name(conversation, user_id, user_names) do
    other_participant =
      Enum.find(conversation.participants, fn p -> p.user_id != user_id end)

    case other_participant do
      nil -> "Unknown"
      p -> Map.get(user_names, p.user_id, "Unknown")
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

  defp user_resolver do
    Application.get_env(:klass_hero, :messaging)[:for_resolving_users]
  end
end
