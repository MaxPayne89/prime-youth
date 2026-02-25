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

  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :invite_resend_requested} = event) do
    %{provider_id: provider_id, invite_id: invite_id, program_id: program_id} = event.payload

    Logger.info("[EnqueueInviteEmails] Processing resend request",
      provider_id: provider_id,
      invite_id: invite_id,
      program_id: program_id
    )

    {:ok, pairs} = UseCase.execute([program_id], provider_id)

    # Trigger: UseCase returns ALL pending invites without tokens in this program
    # Why: other invites may be pending from a recent bulk import — only the
    #      explicitly requested invite should get an immediate email
    # Outcome: tokens are generated for all (correct), but only the resend
    #          target gets an Oban job
    pairs_for_invite = Enum.filter(pairs, fn {id, _name} -> id == invite_id end)

    if pairs_for_invite != [] do
      jobs =
        Enum.map(pairs_for_invite, fn {id, program_name} ->
          SendInviteEmailWorker.new(%{invite_id: id, program_name: program_name})
        end)

      Oban.insert_all(jobs)

      Logger.info("[EnqueueInviteEmails] Enqueued resend email", count: length(jobs))
    end

    :ok
  end
end
