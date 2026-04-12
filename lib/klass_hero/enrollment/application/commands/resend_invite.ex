defmodule KlassHero.Enrollment.Application.Commands.ResendInvite do
  @moduledoc """
  Resets an invite to pending and dispatches the email pipeline.

  1. Fetch invite by ID
  2. Check resendable? domain predicate
  3. Reset status to pending, clear token + invite_sent_at
  4. Dispatch invite_resend_requested event for the invite's program

  The existing EnqueueInviteEmails event handler picks up the reset
  invite and re-sends the email with a fresh token.
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Enrollment.Domain.Models.BulkEnrollmentInvite
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  @invite_reader Application.compile_env!(
                   :klass_hero,
                   [:enrollment, :for_querying_bulk_enrollment_invites]
                 )
  @invite_repository Application.compile_env!(
                       :klass_hero,
                       [:enrollment, :for_storing_bulk_enrollment_invites]
                     )

  @spec execute(binary(), binary()) ::
          {:ok, struct()} | {:error, :not_found | :not_resendable | term()}
  def execute(invite_id, provider_id) when is_binary(invite_id) and is_binary(provider_id) do
    with invite when not is_nil(invite) <- @invite_reader.get_by_id(invite_id),
         # Trigger: invite_id comes from untrusted client params
         # Why: without ownership check, any provider could resend another's invite
         # Outcome: return :not_found to avoid leaking invite existence
         :owned <- if(invite.provider_id == provider_id, do: :owned, else: :not_owned),
         true <- BulkEnrollmentInvite.resendable?(invite),
         {:ok, reset} <- @invite_repository.reset_for_resend(invite),
         # Trigger: invite reset to pending without token
         # Why: dedicated event distinguishes single resend from bulk import
         # Outcome: EnqueueInviteEmails assigns new token + enqueues Oban job
         :ok <-
           EnrollmentEvents.invite_resend_requested(
             reset.provider_id,
             reset.id,
             reset.program_id
           )
           |> EventDispatchHelper.dispatch_or_error(KlassHero.Enrollment) do
      Logger.info("[ResendInvite] Invite reset and event dispatched",
        invite_id: invite_id,
        program_id: reset.program_id
      )

      {:ok, reset}
    else
      nil -> {:error, :not_found}
      :not_owned -> {:error, :not_found}
      false -> {:error, :not_resendable}
      {:error, reason} -> {:error, reason}
    end
  end
end
