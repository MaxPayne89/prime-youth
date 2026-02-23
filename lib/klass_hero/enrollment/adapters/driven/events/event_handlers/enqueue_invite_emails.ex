defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmails do
  @moduledoc """
  Domain event handler that generates invite tokens and enqueues
  Oban jobs to send invitation emails.

  Triggered by `:bulk_invites_imported` on the Enrollment DomainEventBus.

  ## Idempotency

  Queries only invites with `status = "pending" AND invite_token IS NULL`.
  Re-dispatching the event won't duplicate email sends.
  """

  alias KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorker
  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])
  @program_catalog_acl Application.compile_env!(:klass_hero, [
                         :enrollment,
                         :for_resolving_program_catalog
                       ])

  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :bulk_invites_imported} = event) do
    %{provider_id: provider_id, program_ids: program_ids, count: count} = event.payload

    Logger.info("[EnqueueInviteEmails] Processing bulk import event",
      provider_id: provider_id,
      program_count: length(program_ids),
      count: count
    )

    pending_invites = @invite_repository.list_pending_without_token(program_ids)

    if pending_invites == [] do
      Logger.info("[EnqueueInviteEmails] No pending invites to process")
      :ok
    else
      process_invites(pending_invites, provider_id)
    end
  end

  defp process_invites(invites, provider_id) do
    # Trigger: program_id -> program_name lookup needed for email subjects
    # Why: invite schema stores program_id but email needs human-readable name
    # Outcome: reverse the title->id ACL map to get id->title
    programs_by_id = build_programs_by_id(provider_id)

    id_token_pairs = Enum.map(invites, fn invite -> {invite.id, generate_token()} end)
    {:ok, _count} = @invite_repository.bulk_assign_tokens(id_token_pairs)

    jobs =
      Enum.map(invites, fn invite ->
        program_name = Map.get(programs_by_id, invite.program_id, "Program")

        SendInviteEmailWorker.new(%{
          invite_id: invite.id,
          program_name: program_name
        })
      end)

    Oban.insert_all(jobs)

    Logger.info("[EnqueueInviteEmails] Enqueued invite emails", count: length(jobs))
    :ok
  end

  defp build_programs_by_id(provider_id) do
    @program_catalog_acl.list_program_titles_for_provider(provider_id)
    |> Map.new(fn {title, id} -> {id, title} end)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
