defmodule PrimeYouth.Auth.Domain.Ports.ForStoringUsers do
  @moduledoc """
  Secondary port: the application needs this for all persistence operations.
  This consolidates user data, session tokens, email tokens, and password reset tokens.
  Infrastructure provides the actual implementation (typically Ecto-based).
  """

  alias PrimeYouth.Auth.Domain.Models.User

  @type user_id :: integer()
  @type token :: binary()
  @type token_context :: :confirmation | :magic_link | :change_email

  # User operations

  @callback find_by_id(user_id()) :: {:ok, User.t()} | {:error, :not_found}
  @callback find_by_email(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  @callback save(User.t()) :: {:ok, User.t()} | {:error, term()}
  @callback update(User.t()) :: {:ok, User.t()} | {:error, term()}
  @callback update_email(User.t(), String.t()) :: {:ok, User.t()} | {:error, term()}
  @callback update_password(User.t(), String.t()) :: {:ok, User.t()} | {:error, term()}

  # Session token operations

  @callback generate_session_token(User.t()) :: {:ok, token()} | {:error, term()}
  @callback find_by_session_token(token()) ::
              {:ok, {User.t(), DateTime.t()}} | {:error, :not_found}
  @callback delete_session_token(token()) :: :ok | {:error, term()}
  @callback delete_all_session_tokens_for_user(User.t()) :: :ok | {:error, term()}

  # Email token operations (confirmation, magic link, change email)

  @callback generate_email_token(User.t(), token_context()) :: {:ok, token()} | {:error, term()}
  @callback verify_email_token(token(), token_context()) ::
              {:ok, User.t()} | {:error, :invalid_token | :expired | term()}
  @callback delete_email_tokens_for_user(User.t(), token_context()) ::
              :ok | {:error, term()}

  # Password reset token operations

  @callback generate_password_reset_token(User.t()) :: {:ok, token()} | {:error, term()}
  @callback verify_password_reset_token(token()) ::
              {:ok, User.t()} | {:error, :invalid_token | :expired | term()}
  @callback delete_password_reset_tokens_for_user(User.t()) :: :ok | {:error, term()}
end
