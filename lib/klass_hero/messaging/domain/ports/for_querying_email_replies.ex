defmodule KlassHero.Messaging.Domain.Ports.ForQueryingEmailReplies do
  @moduledoc """
  Read-only port for querying email replies in the Messaging bounded context.

  Separated from `ForManagingEmailReplies` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Messaging.Domain.Models.EmailReply

  @callback get_by_id(id :: binary()) ::
              {:ok, EmailReply.t()} | {:error, :not_found}

  @callback list_by_email(inbound_email_id :: binary()) ::
              {:ok, [EmailReply.t()]}
end
