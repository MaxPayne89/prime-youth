defmodule KlassHero.Messaging.Domain.Ports.ForManagingAttachments do
  @moduledoc """
  Repository port for managing message attachments.

  Attachments are child entities of Messages — they have no independent
  lifecycle. Creation is always in the context of a message, and deletion
  is handled by DB cascade (ON DELETE CASCADE from messages table).
  """

  alias KlassHero.Messaging.Domain.Models.Attachment

  @doc """
  Bulk-inserts attachments for a message.

  All attachments must belong to the same message.
  """
  @callback create_many([map()]) :: {:ok, [Attachment.t()]} | {:error, term()}

  @doc """
  Lists attachments for a single message.
  """
  @callback list_for_message(message_id :: String.t()) :: [Attachment.t()]

  @doc """
  Batch-fetches attachments for multiple messages.

  Returns a map of message_id => [attachments]. Messages with no
  attachments are omitted from the map.
  """
  @callback list_for_messages([message_id :: String.t()]) :: %{String.t() => [Attachment.t()]}

  @doc """
  Queries storage paths for attachments belonging to the given conversations.

  Used by the retention policy to collect S3 object keys for cleanup before
  hard-deleting messages (which cascade-deletes attachment records).

  Does NOT delete records — the caller handles that via message deletion.
  """
  @callback get_storage_paths_for_conversations([conversation_id :: String.t()]) ::
              {:ok, [String.t()]} | {:error, term()}
end
