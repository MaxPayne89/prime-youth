defmodule KlassHero.Messaging.Domain.Ports.ForManagingInboundEmails do
  @moduledoc """
  Write-only port for managing inbound emails in the Messaging bounded context.

  Read operations are defined in `ForQueryingInboundEmails`.
  """

  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @callback create(attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}

  @callback update_status(id :: binary(), status :: String.t(), attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}

  @callback update_content(id :: binary(), attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}
end
