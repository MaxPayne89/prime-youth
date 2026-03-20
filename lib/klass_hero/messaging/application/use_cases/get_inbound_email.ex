defmodule KlassHero.Messaging.Application.UseCases.GetInboundEmail do
  @moduledoc """
  Use case for retrieving an inbound email, optionally marking it as read.
  """

  alias KlassHero.Messaging.Domain.Models.InboundEmail
  alias KlassHero.Messaging.Repositories

  @spec execute(String.t(), keyword()) :: {:ok, InboundEmail.t()} | {:error, :not_found}
  def execute(id, opts \\ []) do
    repo = Repositories.inbound_emails()
    mark_read = Keyword.get(opts, :mark_read, false)
    reader_id = Keyword.get(opts, :reader_id)

    with {:ok, email} <- repo.get_by_id(id) do
      if mark_read && reader_id do
        # Trigger: admin opens email with explicit mark_read intent and reader identity
        # Why: domain model encodes status transition rules and idempotency
        # Outcome: unread → read with reader tracked; already-read/archived unchanged
        {:ok, marked} = InboundEmail.mark_read(email, reader_id)

        if marked.status == email.status do
          {:ok, email}
        else
          repo.update_status(id, to_string(marked.status), %{
            read_by_id: marked.read_by_id,
            read_at: marked.read_at
          })
        end
      else
        {:ok, email}
      end
    end
  end
end
