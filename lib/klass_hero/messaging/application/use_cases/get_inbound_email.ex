defmodule KlassHero.Messaging.Application.UseCases.GetInboundEmail do
  @moduledoc """
  Use case for retrieving an inbound email, optionally marking it as read.
  """

  alias KlassHero.Messaging.Repositories

  @spec execute(String.t(), keyword()) :: {:ok, struct()} | {:error, :not_found}
  def execute(id, opts \\ []) do
    repo = Repositories.inbound_emails()
    mark_read = Keyword.get(opts, :mark_read, false)
    reader_id = Keyword.get(opts, :reader_id)

    with {:ok, email} <- repo.get_by_id(id) do
      # Trigger: admin opens an unread email with explicit mark_read intent and a reader identity
      # Why: auto-mark as read so the inbox shows accurate unread state
      # Outcome: status updated to "read" with reader identity tracked; already-read emails unchanged
      if mark_read && email.status == :unread && reader_id do
        repo.update_status(id, "read", %{
          read_by_id: reader_id,
          read_at: DateTime.utc_now()
        })
      else
        {:ok, email}
      end
    end
  end
end
