defmodule KlassHero.Accounts.Application.UseCases.LoginByMagicLink do
  @moduledoc """
  Use case for logging in a user via magic link token.

  Handles three scenarios:
  1. Confirmed user — logs in, expires magic link token
  2. Unconfirmed user (no password) — confirms email, logs in, expires all tokens
  3. Unconfirmed user (has password) — raises security error
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.{TokenCleanup, User, UserToken}
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Logs in a user by magic link token.

  Returns:
  - `{:ok, {%User{}, expired_tokens}}` on success
  - `{:error, :not_found}` if token is invalid/expired
  - Raises on unconfirmed user with password (security violation)
  """
  def execute(token) when is_binary(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Trigger: unconfirmed user has a password set
      # Why: prevents session fixation attacks via magic link
      # Outcome: raises — this state should not occur in default implementation
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      # Trigger: unconfirmed user without password (normal registration flow)
      # Why: first login confirms the email
      # Outcome: user confirmed, all tokens expired, user_confirmed event dispatched
      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> TokenCleanup.update_user_and_delete_all_tokens()
        |> case do
          {:ok, {confirmed_user, tokens}} ->
            DomainEventBus.dispatch(
              KlassHero.Accounts,
              UserEvents.user_confirmed(confirmed_user, %{confirmation_method: :magic_link})
            )

            {:ok, {confirmed_user, tokens}}

          error ->
            error
        end

      # Trigger: confirmed user clicking magic link
      # Why: standard login — just expire the specific token
      # Outcome: user logged in, magic link token deleted
      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end
end
