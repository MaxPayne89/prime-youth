defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.MarkInviteRegistered do
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

  @spec handle(DomainEvent.t()) :: :ok
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

  defp maybe_transition(invite) do
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
end
