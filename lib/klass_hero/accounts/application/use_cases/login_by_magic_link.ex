defmodule KlassHero.Accounts.Application.UseCases.LoginByMagicLink do
  @moduledoc """
  Use case for logging in a user via magic link token.

  Handles three scenarios:
  1. Confirmed user — logs in, expires magic link token
  2. Unconfirmed user (no password) — confirms email, logs in, expires all tokens
  3. Unconfirmed user (has password) — security violation error
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @user_repository Application.compile_env!(
                     :klass_hero,
                     [:accounts, :for_storing_users]
                   )

  @doc """
  Logs in a user by magic link token.

  Returns:
  - `{:ok, {%User{}, expired_tokens}}` on success
  - `{:error, :not_found}` if token is invalid/expired
  - `{:error, :invalid_token}` if token is malformed
  - `{:error, :security_violation}` if unconfirmed user has password
  """
  def execute(token) when is_binary(token) do
    case @user_repository.resolve_magic_link(token) do
      {:ok, {:unconfirmed, user}} ->
        handle_unconfirmed(user)

      {:ok, {:confirmed, user, token_record}} ->
        handle_confirmed(user, token_record)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Trigger: unconfirmed user without password (normal registration flow)
  # Why: first login confirms the email
  # Outcome: user confirmed, all tokens expired, user_confirmed event dispatched
  defp handle_unconfirmed(user) do
    case @user_repository.confirm_and_cleanup_tokens(user) do
      {:ok, {confirmed_user, tokens}} ->
        UserEvents.user_confirmed(confirmed_user, %{confirmation_method: :magic_link})
        |> dispatch_event(:user_confirmed)

        {:ok, {confirmed_user, tokens}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Trigger: confirmed user clicking magic link
  # Why: standard login — just expire the specific token
  # Outcome: user logged in, magic link token deleted
  defp handle_confirmed(user, token_record) do
    @user_repository.delete_token(token_record)
    {:ok, {user, []}}
  end

  defp dispatch_event(event, event_type) do
    case DomainEventBus.dispatch(KlassHero.Accounts, event) do
      :ok ->
        :ok

      {:error, failures} ->
        Logger.warning("Event dispatch failed",
          event_type: event_type,
          failures: inspect(failures)
        )
    end
  end
end
