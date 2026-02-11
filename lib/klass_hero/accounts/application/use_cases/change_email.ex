defmodule KlassHero.Accounts.Application.UseCases.ChangeEmail do
  @moduledoc """
  Use case for updating a user's email via confirmation token.

  Orchestrates the 5-step email change flow:
  1. Verify the change token
  2. Fetch the token + new email
  3. Update the user's email
  4. Delete all change tokens for this context
  5. Publish user_email_changed event
  """

  import Ecto.Query, warn: false

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.{User, UserToken}
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Updates the user's email using the given confirmation token.

  Returns:
  - `{:ok, %User{}}` on success
  - `{:error, :invalid_token}` if token is invalid or expired
  - `{:error, changeset}` if email update fails
  """
  def execute(%User{} = user, token) when is_binary(token) do
    context = "change:#{user.email}"
    previous_email = user.email

    Ecto.Multi.new()
    |> Ecto.Multi.run(:verify_token, fn _repo, _ ->
      UserToken.verify_change_email_token_query(token, context)
    end)
    |> Ecto.Multi.run(:fetch_token, fn repo, %{verify_token: query} ->
      case repo.one(query) do
        %UserToken{sent_to: email} = token -> {:ok, {token, email}}
        nil -> {:error, :token_not_found}
      end
    end)
    |> Ecto.Multi.run(:update_email, fn repo, %{fetch_token: {_token, email}} ->
      user
      |> User.email_changeset(%{email: email})
      |> repo.update()
    end)
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{update_email: updated_user} ->
      from(UserToken, where: [user_id: ^updated_user.id, context: ^context])
    end)
    |> Ecto.Multi.run(:publish_event, fn _repo, %{update_email: updated_user} ->
      DomainEventBus.dispatch(
        KlassHero.Accounts,
        UserEvents.user_email_changed(updated_user, %{previous_email: previous_email})
      )

      {:ok, updated_user}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{publish_event: user}} -> {:ok, user}
      {:error, :verify_token, _reason, _} -> {:error, :invalid_token}
      {:error, :fetch_token, _reason, _} -> {:error, :invalid_token}
      {:error, :update_email, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end
end
