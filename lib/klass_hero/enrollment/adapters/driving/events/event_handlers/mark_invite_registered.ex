defmodule KlassHero.Enrollment.Adapters.Driving.Events.EventHandlers.MarkInviteRegistered do
  @moduledoc """
  Domain event handler that transitions an invite from invite_sent to registered
  when the guardian claims the invite link.

  Triggered by `:invite_claimed` on the Enrollment DomainEventBus.
  Idempotent: skips if invite is already registered or beyond.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @invite_repository Application.compile_env!(
                       :klass_hero,
                       [:enrollment, :for_storing_bulk_enrollment_invites]
                     )

  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :invite_claimed} = event) do
    %{invite_id: invite_id} = event.payload

    case @invite_repository.get_by_id(invite_id) do
      nil ->
        Logger.warning("[MarkInviteRegistered] Invite not found", invite_id: invite_id)
        :ok

      invite ->
        maybe_transition(invite)
    end
  end

  # Trigger: invite is already at or beyond the registered state
  # Why: claiming is idempotent — replaying the event must not regress status
  # Outcome: silently succeeds without touching the database
  defp maybe_transition(%{status: status}) when status in ["registered", "enrolled"] do
    :ok
  end

  # Trigger: invite is in "invite_sent" status (the only valid source for this transition)
  # Why: state machine allows invite_sent → registered; other statuses must not regress
  # Outcome: transitions to registered, or returns error if persistence fails
  defp maybe_transition(%{status: "invite_sent"} = invite) do
    case @invite_repository.transition_status(invite, %{
           status: "registered",
           registered_at: DateTime.utc_now() |> DateTime.truncate(:second)
         }) do
      {:ok, _} ->
        Logger.info("[MarkInviteRegistered] Invite transitioned to registered",
          invite_id: invite.id
        )

        :ok

      {:error, reason} ->
        Logger.error("[MarkInviteRegistered] Failed to transition invite",
          invite_id: invite.id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Trigger: invite is in an unexpected status (not registered/enrolled, not invite_sent)
  # Why: statuses like "pending" or "failed" are not valid sources for this transition
  # Outcome: log warning and return :ok (idempotent no-op)
  defp maybe_transition(%{status: status} = invite) do
    Logger.warning("[MarkInviteRegistered] Unexpected status, skipping",
      invite_id: invite.id,
      status: status
    )

    :ok
  end
end
