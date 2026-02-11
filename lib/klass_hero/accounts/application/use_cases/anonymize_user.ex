defmodule KlassHero.Accounts.Application.UseCases.AnonymizeUser do
  @moduledoc """
  Use case for GDPR account anonymization.

  Orchestrates:
  1. Anonymize user PII (email, name, avatar)
  2. Delete all tokens (invalidate all sessions)
  3. Publish user_anonymized event for downstream contexts
  """

  import Ecto.Query, warn: false

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.{User, UserToken}
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Anonymizes a user account.

  Returns:
  - `{:ok, %User{}}` on success (dispatches user_anonymized event)
  - `{:error, :user_not_found}` if nil user
  - `{:error, changeset}` on update failure
  """
  def execute(%User{} = user) do
    previous_email = user.email

    Ecto.Multi.new()
    |> Ecto.Multi.update(:anonymize_user, User.anonymize_changeset(user))
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{anonymize_user: anonymized_user} ->
      from(t in UserToken, where: t.user_id == ^anonymized_user.id)
    end)
    |> Ecto.Multi.run(:publish_event, fn _repo, %{anonymize_user: anonymized_user} ->
      DomainEventBus.dispatch(
        KlassHero.Accounts,
        UserEvents.user_anonymized(anonymized_user, %{previous_email: previous_email})
      )

      {:ok, anonymized_user}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{publish_event: user}} -> {:ok, user}
      {:error, :anonymize_user, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def execute(nil), do: {:error, :user_not_found}
end
