defmodule KlassHero.Messaging.Domain.Ports.ForManagingAttachments do
  @moduledoc """
  Write-only port for managing message attachments.

  Attachments are child entities of Messages — they have no independent
  lifecycle. Creation is always in the context of a message, and deletion
  is handled by DB cascade (ON DELETE CASCADE from messages table).

  Read operations are defined in `ForQueryingAttachments`.
  """

  @doc """
  Bulk-inserts attachments for a message.

  All attachments must belong to the same message.
  """
  @callback create_many([map()]) :: {:ok, [term()]} | {:error, term()}
end
