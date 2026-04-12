defmodule KlassHero.Messaging.Application.Commands.UpdateInboundEmailContent do
  @moduledoc """
  Command for updating inbound email content fields (body, headers, content_status).
  """

  @inbound_email_repo Application.compile_env!(:klass_hero, [
                        :messaging,
                        :for_managing_inbound_emails
                      ])

  @doc """
  Updates content fields for an inbound email.

  ## Parameters
  - id: The inbound email ID
  - attrs: Map of content attributes to update

  ## Returns
  - `{:ok, email}` - Updated email
  - `{:error, reason}` - Failure
  """
  @spec execute(String.t(), map()) :: {:ok, struct()} | {:error, term()}
  def execute(id, attrs) do
    @inbound_email_repo.update_content(id, attrs)
  end
end
