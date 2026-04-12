defmodule KlassHero.Messaging.Application.Commands.UpdateInboundEmailStatus do
  @moduledoc """
  Command for updating the status of an inbound email.
  """

  @inbound_email_repo Application.compile_env!(:klass_hero, [
                        :messaging,
                        :for_managing_inbound_emails
                      ])

  @doc """
  Updates the status of an inbound email.

  ## Parameters
  - id: The email ID
  - status: The new status string ("unread", "read", "archived")
  - attrs: Additional attributes to update

  ## Returns
  - `{:ok, email}` - Updated email
  - `{:error, reason}` - Failure
  """
  @spec execute(String.t(), String.t(), map()) :: {:ok, struct()} | {:error, term()}
  def execute(id, status, attrs \\ %{}) do
    @inbound_email_repo.update_status(id, status, attrs)
  end
end
