defmodule PrimeYouthWeb.ProviderAuth do
  @moduledoc """
  Provider authorization module for protecting provider-specific routes.

  This module ensures that only authenticated users with associated provider
  accounts can access provider-specific functionality (dashboard, program management).

  ## Usage

  Add to LiveView `on_mount` hook:

      live_session :provider,
        on_mount: [{PrimeYouthWeb.ProviderAuth, :require_provider}] do
        live "/provider/dashboard", ProviderLive.Dashboard, :index
      end

  Or use in LiveView directly:

      defmodule MyAppWeb.ProviderLive do
        use MyAppWeb, :live_view

        on_mount {PrimeYouthWeb.ProviderAuth, :require_provider}
      end
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.ProviderRepository

  @doc """
  Ensures the current user has an associated provider account.

  Requires authentication first (use with `:require_authenticated` from UserAuth).
  Redirects to home page if user has no provider account.
  Assigns `:current_provider` to socket if authorized.
  """
  def on_mount(:require_provider, _params, _session, socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id

      case ProviderRepository.get_by_user_id(user_id) do
        {:ok, provider} ->
          {:cont, assign(socket, :current_provider, provider)}

        {:error, :not_found} ->
          socket =
            socket
            |> put_flash(:error, "You must have a provider account to access this page.")
            |> redirect(to: "/")

          {:halt, socket}
      end
    else
      socket =
        socket
        |> put_flash(:error, "You must log in to access this page.")
        |> redirect(to: "/users/log-in")

      {:halt, socket}
    end
  end
end
