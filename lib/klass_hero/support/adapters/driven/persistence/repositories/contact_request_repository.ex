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
    Logger.info("""
    Contact Form Submission:
    ID: #{contact_request.id}
    Name: #{contact_request.name}
    Email: #{contact_request.email}
    Subject: #{contact_request.subject}
    Message: #{contact_request.message}
    Submitted At: #{DateTime.to_iso8601(contact_request.submitted_at)}
    """)

    {:ok, contact_request}
  end
end
