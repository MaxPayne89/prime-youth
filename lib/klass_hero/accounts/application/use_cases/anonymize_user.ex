defmodule KlassHero.Accounts.Application.UseCases.AnonymizeUser do
  @moduledoc """
  Use case for GDPR account anonymization.

  Orchestrates:
  1. Anonymize user PII and delete all tokens (via repository)
  2. Publish user_anonymized event for downstream contexts
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Shared.EventDispatchHelper

  @user_repository Application.compile_env!(
                     :klass_hero,
                     [:accounts, :for_storing_users]
                   )

  @doc """
  Anonymizes a user account.

  Returns:
  - `{:ok, %User{}}` on success (dispatches user_anonymized event)
  - `{:error, :user_not_found}` if nil user
  - `{:error, changeset}` on update failure
  """
  def execute(%{email: _} = user) do
    previous_email = user.email

    case @user_repository.anonymize(user) do
      {:ok, anonymized_user} ->
        # Trigger: GDPR-critical event — log at error level if dispatch fails
        # Why: anonymization events drive downstream data deletion
        # Outcome: primary operation still succeeds, but failure is escalated
        UserEvents.user_anonymized(anonymized_user, %{previous_email: previous_email})
        |> EventDispatchHelper.dispatch(KlassHero.Accounts)

        {:ok, anonymized_user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(nil), do: {:error, :user_not_found}
end
