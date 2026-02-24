defmodule KlassHero.Enrollment.Application.UseCases.ClaimInvite do
  @moduledoc """
  Use case for claiming a bulk enrollment invite by token.

  Validates the token, resolves or creates the user account, and publishes
  the `:invite_claimed` event to trigger the async saga (child creation,
  enrollment).
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  @invite_repository Application.compile_env!(
                       :klass_hero,
                       [:enrollment, :for_storing_bulk_enrollment_invites]
                     )
  @user_accounts Application.compile_env!(
                   :klass_hero,
                   [:enrollment, :for_resolving_user_accounts]
                 )

  @doc """
  Claims an invite by its token.

  Returns:
  - `{:ok, :new_user, user, invite}` — new account created
  - `{:ok, :existing_user, user, invite}` — existing account found
  - `{:error, :not_found}` — invalid or expired token
  - `{:error, :already_claimed}` — invite already processed
  """
  def execute(token) when is_binary(token) do
    with {:ok, invite} <- find_invite(token),
         {:ok, invite} <- validate_claimable(invite),
         {:ok, user_type, user} <- resolve_user(invite),
         :ok <- publish_invite_claimed(invite, user) do
      Logger.info("[ClaimInvite] Claimed invite",
        invite_id: invite.id,
        user_type: user_type,
        user_id: user.id
      )

      {:ok, user_type, user, invite}
    end
  end

  defp find_invite(token) do
    case @invite_repository.get_by_token(token) do
      nil -> {:error, :not_found}
      invite -> {:ok, invite}
    end
  end

  # Trigger: invite status is not "invite_sent"
  # Why: only freshly-sent invites may be claimed; any other status means
  #      the invite was already processed (registered, enrolled, error, etc.)
  # Outcome: short-circuits with :already_claimed
  defp validate_claimable(%{status: "invite_sent"} = invite), do: {:ok, invite}
  defp validate_claimable(_invite), do: {:error, :already_claimed}

  # Trigger: guardian_email already exists in the Accounts context
  # Why: returning parents should not get a duplicate account; instead we
  #      link the invite to their existing user record
  # Outcome: returns :existing_user so the caller (and downstream saga) can
  #          skip the onboarding flow
  defp resolve_user(invite) do
    case @user_accounts.get_user_by_email(invite.guardian_email) do
      %{} = user ->
        {:ok, :existing_user, user}

      nil ->
        register_new_user(invite)
    end
  end

  defp register_new_user(invite) do
    attrs = %{
      name: guardian_name(invite),
      email: invite.guardian_email,
      intended_roles: [:parent]
    }

    case @user_accounts.register_user(attrs) do
      {:ok, user} -> {:ok, :new_user, user}
      {:error, reason} -> {:error, reason}
    end
  end

  defp guardian_name(invite) do
    case {invite.guardian_first_name, invite.guardian_last_name} do
      {nil, nil} -> invite.guardian_email
      {first, nil} -> first
      {nil, last} -> last
      {first, last} -> "#{first} #{last}"
    end
  end

  defp publish_invite_claimed(invite, user) do
    EnrollmentEvents.invite_claimed(invite.id, %{
      invite_id: invite.id,
      user_id: user.id,
      program_id: invite.program_id,
      provider_id: invite.provider_id,
      child_first_name: invite.child_first_name,
      child_last_name: invite.child_last_name,
      child_date_of_birth: invite.child_date_of_birth,
      guardian_email: invite.guardian_email,
      guardian_first_name: invite.guardian_first_name,
      guardian_last_name: invite.guardian_last_name,
      school_grade: invite.school_grade,
      school_name: invite.school_name,
      medical_conditions: invite.medical_conditions,
      nut_allergy: invite.nut_allergy,
      consent_photo_marketing: invite.consent_photo_marketing,
      consent_photo_social_media: invite.consent_photo_social_media
    })
    |> EventDispatchHelper.dispatch_or_error(KlassHero.Enrollment)
  end
end
