defmodule KlassHero.Enrollment.Application.UseCases.ResendInvite do
  @moduledoc """
  Resets an invite to pending and dispatches the email pipeline.

  1. Fetch invite by ID
  2. Reset status to pending, clear token + invite_sent_at
  3. Dispatch bulk_invites_imported event for the invite's program

  The existing EnqueueInviteEmails event handler picks up the reset
  invite and re-sends the email with a fresh token.
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  @invite_repository Application.compile_env!(
                       :klass_hero,
                       [:enrollment, :for_storing_bulk_enrollment_invites]
                     )

  @spec execute(binary()) :: {:ok, struct()} | {:error, :not_found | :not_resendable}
  def execute(invite_id) when is_binary(invite_id) do
    with invite when not is_nil(invite) <- @invite_repository.get_by_id(invite_id),
         {:ok, reset} <- @invite_repository.reset_for_resend(invite) do
      # Trigger: invite reset to pending without token
      # Why: existing email pipeline processes pending invites without tokens
      # Outcome: EnqueueInviteEmails assigns new token + enqueues Oban job
      EnrollmentEvents.bulk_invites_imported(reset.provider_id, [reset.program_id], 1)
      |> EventDispatchHelper.dispatch(KlassHero.Enrollment)

      Logger.info("[ResendInvite] Invite reset and event dispatched",
        invite_id: invite_id,
        program_id: reset.program_id
      )

      {:ok, reset}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
