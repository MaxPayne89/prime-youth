defmodule KlassHero.Messaging.Domain.Ports.ForManagingEmailReplies do
  @moduledoc """
  Repository port for managing email replies in the Messaging bounded context.
  """

  alias KlassHero.Messaging.Domain.Models.EmailReply

  @callback create(attrs :: map()) ::
              {:ok, EmailReply.t()} | {:error, term()}

  @callback get_by_id(id :: binary()) ::
              {:ok, EmailReply.t()} | {:error, :not_found}

  @callback update_status(id :: binary(), status :: String.t(), attrs :: map()) ::
              {:ok, EmailReply.t()} | {:error, term()}

  @callback list_by_email(inbound_email_id :: binary()) ::
              {:ok, [EmailReply.t()]}
end
