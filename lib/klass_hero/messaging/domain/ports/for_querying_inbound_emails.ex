defmodule KlassHero.Messaging.Domain.Ports.ForQueryingInboundEmails do
  @moduledoc """
  Read-only port for querying inbound emails in the Messaging bounded context.

  Separated from `ForManagingInboundEmails` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @callback get_by_id(id :: binary()) ::
              {:ok, InboundEmail.t()} | {:error, :not_found}

  @callback get_by_resend_id(resend_id :: String.t()) ::
              {:ok, InboundEmail.t()} | {:error, :not_found}

  @doc """
  Lists inbound emails with pagination and filtering.

  Options:
  - limit: integer (default 50)
  - status: :unread | :read | :archived | nil (all)
  - before: DateTime (cursor pagination)
  """
  @callback list(opts :: keyword()) ::
              {:ok, [InboundEmail.t()], has_more :: boolean()}

  @callback count_by_status(status :: atom()) :: non_neg_integer()
end
