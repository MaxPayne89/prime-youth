defmodule KlassHero.Messaging.Application.Queries.ListInboundEmails do
  @moduledoc """
  Use case for listing inbound emails with filtering and pagination.

  Delegates to the inbound email repository with opts passthrough.
  """

  @inbound_email_reader Application.compile_env!(:klass_hero, [
                          :messaging,
                          :for_querying_inbound_emails
                        ])

  @spec execute(keyword()) :: {:ok, [struct()], boolean()}
  def execute(opts \\ []) do
    @inbound_email_reader.list(opts)
  end
end
