defmodule KlassHero.Messaging.Application.UseCases.ListInboundEmails do
  @moduledoc """
  Use case for listing inbound emails with filtering and pagination.

  Delegates to the inbound email repository with opts passthrough.
  """

  alias KlassHero.Messaging.Repositories

  @spec execute(keyword()) :: {:ok, [struct()], boolean()}
  def execute(opts \\ []) do
    Repositories.inbound_emails().list(opts)
  end
end
