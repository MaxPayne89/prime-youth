defmodule KlassHero.Messaging.Domain.Ports.ForManagingEmailReplies do
  @moduledoc """
  Write-only port for managing email replies in the Messaging bounded context.

  Read operations are defined in `ForQueryingEmailReplies`.
  """

  alias KlassHero.Messaging.Domain.Models.EmailReply

  @callback create(attrs :: map()) ::
              {:ok, EmailReply.t()} | {:error, term()}

  @callback update_status(id :: binary(), status :: String.t(), attrs :: map()) ::
              {:ok, EmailReply.t()} | {:error, term()}
end
