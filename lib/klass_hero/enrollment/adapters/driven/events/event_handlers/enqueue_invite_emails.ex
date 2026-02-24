defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmails do
  @moduledoc """
  Event handler adapter that delegates to the EnqueueInviteEmails use case
  and maps the result into Oban jobs.

  Triggered by `:bulk_invites_imported` on the Enrollment DomainEventBus.
  """

  alias KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorker
  alias KlassHero.Enrollment.Application.UseCases.EnqueueInviteEmails, as: UseCase
  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :bulk_invites_imported} = event) do
    %{provider_id: provider_id, program_ids: program_ids, count: count} = event.payload

    Logger.info("[EnqueueInviteEmails] Processing bulk import event",
      provider_id: provider_id,
      program_count: length(program_ids),
      count: count
    )

    {:ok, pairs} = UseCase.execute(program_ids, provider_id)

    if pairs != [] do
      jobs =
        Enum.map(pairs, fn {invite_id, program_name} ->
          SendInviteEmailWorker.new(%{invite_id: invite_id, program_name: program_name})
        end)

      Oban.insert_all(jobs)

      Logger.info("[EnqueueInviteEmails] Enqueued invite emails", count: length(jobs))
    end

    :ok
  end
end
