defmodule PrimeYouth.Auth.Adapters.Driven.Notifications.UserNotifier do
  import Swoosh.Email

  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserTokenSchema
  alias PrimeYouth.Mailer
  alias PrimeYouth.Repo

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"PrimeYouth", "contact@example.com"})
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
    final_url = build_url(user, url, "change:email")

    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{final_url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %PrimeYouth.Auth.Domain.Models.User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    token_or_url = build_url(user, url, "login")

    # Build full URL for email body (token may have [TOKEN] markers for tests)
    final_url = if is_function(url), do: "/users/log-in/#{token_or_url}", else: token_or_url

    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{final_url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to confirm a user account.
  """
  def deliver_confirmation_instructions(user, url) do
    # Use "login" context for both magic link login and confirmation
    # The route /users/log-in/:token handles both cases
    token_or_url = build_url(user, url, "login")

    # Build full URL for email body (token may have [TOKEN] markers for tests)
    final_url = if is_function(url), do: "/users/log-in/#{token_or_url}", else: token_or_url

    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{final_url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    final_url = build_url(user, url, "reset_password")

    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{final_url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  # Helper to build URLs - handles both string URLs (production) and function URLs (tests)
  defp build_url(user, url, context) do
    if is_function(url) do
      # Test mode: generate token, insert it, and call url function with JUST the token
      # The url function will wrap the token with [TOKEN] markers for extraction
      # The email body will construct the full path around the wrapped token
      {encoded_token, user_token} = UserTokenSchema.build_email_token(user, context)
      Repo.insert!(user_token)
      url.(encoded_token)
    else
      # Production mode: url is already a complete string
      url
    end
  end
end
