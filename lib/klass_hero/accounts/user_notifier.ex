defmodule KlassHero.Accounts.UserNotifier do
  @moduledoc """
  Handles email notifications for user account operations.

  Delivers emails for account confirmation, magic link authentication,
  password resets, and email change confirmations using Swoosh.
  """

  import Swoosh.Email

  alias KlassHero.Accounts.User
  alias KlassHero.Mailer

  @from Application.compile_env!(:klass_hero, [:mailer_defaults, :from])

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(@from)
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Delivers a staff invitation email with a registration link.

  Accepts a pre-built URL or a raw invitation token. When a token is provided
  the registration URL is constructed from the application endpoint.
  """
  def deliver_staff_invitation(
        email,
        %{business_name: business_name, first_name: first_name},
        url_or_token
      ) do
    url = build_invitation_url(url_or_token)

    deliver(email, "You've been invited to join #{business_name} on Klass Hero", """
    Hi #{first_name},

    #{business_name} has invited you to join their team on Klass Hero.

    Klass Hero is a platform for managing afterschool activities, camps, and class trips.

    Click the link below to complete your registration:

    #{url}

    This invitation expires in 7 days.

    If you did not expect this invitation, you can ignore this email.
    """)
  end

  # Accepts either a full URL (starting with "http") or a raw token,
  # constructing the full registration URL from the endpoint in the latter case.
  defp build_invitation_url("http" <> _ = url), do: url

  defp build_invitation_url(raw_token) do
    "#{KlassHeroWeb.Endpoint.url()}/users/staff-invitation/#{raw_token}"
  end

  @doc """
  Delivers a notification email when an existing user is added as a staff member.
  """
  def deliver_staff_added_notification(email, %{business_name: business_name}) do
    deliver(email, "You've been added to #{business_name}'s team on Klass Hero", """
    Hi,

    #{business_name} has added you to their team on Klass Hero.

    You can view your assigned programs on your staff dashboard:

    #{KlassHeroWeb.Endpoint.url()}/staff/dashboard

    If you did not expect this, please contact #{business_name} directly.
    """)
  end
end
