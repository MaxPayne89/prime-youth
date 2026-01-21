defmodule KlassHero.Support.Adapters.Driven.Persistence.Repositories.ContactRequestRepository do
  @moduledoc """
  Logging-only repository for contact requests.

  This initial implementation logs contact submissions without persisting
  to a database. The repository fulfills the ForContactRequests port contract
  by accepting contact requests and logging them to the application logger.

  Infrastructure errors are not caught - they crash and are handled by
  the supervision tree.
  """

  @behaviour KlassHero.Support.Domain.Ports.ForContactRequests

  alias KlassHero.Support.Domain.Models.ContactRequest

  require Logger

  @impl true
  def submit(%ContactRequest{} = contact_request) do
    Logger.info("Contact form submitted",
      contact_id: contact_request.id,
      name: contact_request.name,
      email: contact_request.email,
      subject: contact_request.subject,
      message: contact_request.message,
      submitted_at: DateTime.to_iso8601(contact_request.submitted_at)
    )

    {:ok, contact_request}
  end
end
