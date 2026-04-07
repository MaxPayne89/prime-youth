defmodule KlassHeroWeb.StripeIdentityReturnController do
  use KlassHeroWeb, :controller

  @doc """
  Handles the return redirect from Stripe after the provider completes (or abandons)
  the hosted Identity verification flow.

  The authoritative verification result arrives via the Stripe webhook — this action
  exists only to give the provider a smooth redirect back to their dashboard.
  The `?session_id` query param appended by Stripe is intentionally ignored here.
  """
  def show(conn, _params) do
    conn
    |> put_flash(
      :info,
      "Identity verification submitted. Your status will update shortly."
    )
    |> redirect(to: ~p"/provider/dashboard")
  end
end
