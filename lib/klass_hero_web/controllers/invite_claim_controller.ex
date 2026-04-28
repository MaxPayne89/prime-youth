defmodule KlassHeroWeb.InviteClaimController do
  @moduledoc """
  Handles GET /invites/:token — the public endpoint a guardian clicks
  from their invite email.

  Delegates to `Enrollment.claim_invite/1` which either creates a new
  user or finds an existing one, then redirects accordingly.
  """

  use KlassHeroWeb, :controller

  alias KlassHero.Accounts
  alias KlassHero.Enrollment
  alias KlassHero.Enrollment.Application.ClaimResult

  require Logger

  def show(conn, %{"token" => token}) do
    case Enrollment.claim_invite(token) do
      {:ok, %ClaimResult{user_type: :new_user, user: user}} ->
        # Trigger: new user account was just created from invite data
        # Why: the user has no password yet; a magic-link login lets them
        #      access the app immediately and set a password in settings
        # Outcome: redirect to magic-link login URL
        # Note: ClaimInvite returns a lightweight map to avoid cross-context
        # type coupling; re-fetch the full %User{} struct for Accounts API
        full_user = Accounts.get_user!(user.id)
        magic_token = Accounts.generate_magic_link_token(full_user)

        conn
        |> put_flash(
          :info,
          gettext("Your account has been created! Set up your password in settings.")
        )
        |> redirect(to: ~p"/users/log-in/#{magic_token}")

      {:ok, %ClaimResult{user_type: :existing_user}} ->
        # Trigger: guardian_email matched an existing user
        # Why: no new account needed; just prompt them to log in so the
        #      enrollment saga can proceed against their existing identity
        # Outcome: redirect to standard login page
        conn
        |> put_flash(
          :info,
          gettext("You already have an account. Log in to see your new enrollment.")
        )
        |> redirect(to: ~p"/users/log-in")

      {:error, :not_found} ->
        Logger.warning("[InviteClaimController] Invalid or expired invite token attempted")

        conn
        |> put_flash(:error, gettext("This invite link is invalid or has expired."))
        |> redirect(to: ~p"/")

      {:error, :already_claimed} ->
        conn
        |> put_flash(:info, gettext("This invite has already been used."))
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
