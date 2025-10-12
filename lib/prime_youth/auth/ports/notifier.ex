defmodule PrimeYouth.Auth.Ports.Notifier do
  @moduledoc """
  Secondary port: the application needs this to send notifications to users.
  Infrastructure provides the actual implementation (typically email-based).
  """

  alias PrimeYouth.Auth.Domain.User

  @type token :: String.t()

  @callback send_confirmation_email(User.t(), token()) :: :ok | {:error, term()}
  @callback send_magic_link_email(User.t(), token()) :: :ok | {:error, term()}
  @callback send_password_reset_email(User.t(), token()) :: :ok | {:error, term()}
  @callback send_email_change_confirmation(User.t(), String.t(), token()) ::
              :ok | {:error, term()}
  @callback send_email_change_notification(User.t(), String.t()) :: :ok | {:error, term()}
  @callback send_password_change_notification(User.t()) :: :ok | {:error, term()}
end
