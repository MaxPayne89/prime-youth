defmodule PrimeYouthWeb.DevAuthToggle do
  @moduledoc """
  Development-only authentication toggle functionality.

  This module provides a convenient way to toggle between authenticated and
  unauthenticated states during development without going through the full
  login flow.

  ## Usage

  Add this to your LiveView module (only in development):

      if Mix.env() == :dev do
        use PrimeYouthWeb.DevAuthToggle
      end

  This will inject a `handle_event("toggle_auth", ...)` implementation that:
  - Assigns a sample user when unauthenticated
  - Clears the user when authenticated (toggles state)

  ## Production Safety

  This module should NEVER be used in production. The `use` statement should
  be wrapped in an environment check to ensure it's only compiled in development.

  In production, use proper authentication through `PrimeYouthWeb.UserAuth`.
  """

  defmacro __using__(_opts) do
    quote do
      @impl true
      def handle_event("toggle_auth", _params, socket) do
        new_user =
          if !socket.assigns.current_user, do: PrimeYouthWeb.Live.SampleFixtures.sample_user()

        {:noreply, assign(socket, current_user: new_user)}
      end
    end
  end
end
