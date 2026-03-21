defmodule KlassHero.Messaging.Domain.Ports.ForManagingInboundEmails do
  @moduledoc """
  Repository port for managing inbound emails in the Messaging bounded context.
  """

  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @callback create(attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}

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

  @callback update_status(id :: binary(), status :: String.t(), attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}

  @callback update_content(id :: binary(), attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}

  @callback count_by_status(status :: atom()) :: non_neg_integer()
end
