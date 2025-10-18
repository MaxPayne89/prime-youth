defmodule PrimeYouth.Auth.Adapters.Driven.Notifications.EmailNotifier do
  @moduledoc """
  Adapter implementing Notifier port using the Accounts.UserNotifier.
  Handles sending various email notifications to users.
  """

  @behaviour PrimeYouth.Auth.Domain.Ports.ForSendingNotifications

  alias PrimeYouth.Auth.Domain.Models.User
  alias PrimeYouth.Auth.Adapters.Driven.Notifications.UserNotifier

  @impl true
  def send_confirmation_email(%User{} = user, token) do
    UserNotifier.deliver_confirmation_instructions(
      %{email: user.email},
      build_url("/users/confirm/#{token}")
    )

    :ok
  rescue
    _ -> {:error, :email_delivery_failed}
  end

  @impl true
  def send_magic_link_email(%User{} = user, token) do
    UserNotifier.deliver_login_instructions(
      %{email: user.email},
      build_url("/users/log-in/#{token}")
    )

    :ok
  rescue
    _ -> {:error, :email_delivery_failed}
  end

  @impl true
  def send_password_reset_email(%User{} = user, token) do
    UserNotifier.deliver_reset_password_instructions(
      %{email: user.email},
      build_url("/users/reset_password/#{token}")
    )

    :ok
  rescue
    _ -> {:error, :email_delivery_failed}
  end

  @impl true
  def send_email_change_confirmation(%User{}, new_email, token) do
    UserNotifier.deliver_update_email_instructions(
      %{email: new_email},
      build_url("/users/settings/confirm-email/#{token}")
    )

    :ok
  rescue
    _ -> {:error, :email_delivery_failed}
  end

  @impl true
  def send_email_change_notification(%User{} = user, old_email) do
    # Send notification to both old and new email addresses
    UserNotifier.deliver_update_email_instructions(
      %{email: old_email},
      build_url("/users/settings")
    )

    UserNotifier.deliver_update_email_instructions(
      %{email: user.email},
      build_url("/users/settings")
    )

    :ok
  rescue
    _ -> {:error, :email_delivery_failed}
  end

  @impl true
  def send_password_change_notification(%User{} = user) do
    # For now, reuse the email change notification
    # In production, you'd want a specific template
    UserNotifier.deliver_update_email_instructions(
      %{email: user.email},
      build_url("/users/settings")
    )

    :ok
  rescue
    _ -> {:error, :email_delivery_failed}
  end

  defp build_url(path) do
    # In production, this would use the actual domain from config
    base_url = Application.get_env(:prime_youth, :base_url, "http://localhost:4000")
    "#{base_url}#{path}"
  end
end
