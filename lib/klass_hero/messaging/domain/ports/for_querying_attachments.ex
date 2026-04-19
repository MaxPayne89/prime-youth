defmodule KlassHero.Messaging.Domain.Ports.ForQueryingAttachments do
  @moduledoc """
  Read-only port for querying message attachments in the Messaging bounded context.

  Separated from `ForManagingAttachments` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Messaging.Domain.Models.Attachment

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
