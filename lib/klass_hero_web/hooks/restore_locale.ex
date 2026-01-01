defmodule KlassHeroWeb.Hooks.RestoreLocale do
  @moduledoc """
  LiveView on_mount hook to restore locale in each LiveView process.

  LiveViews run in isolated processes, so `Gettext.get_locale()` must be
  set for each process. This hook restores the locale from session and
  assigns it to the socket for use in templates.

  ## Usage

  Add to live_session in router:

      live_session :main,
        on_mount: [{KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}] do
        # routes...
      end

  Then access `@locale` in templates for language-aware rendering.
  """

  import Phoenix.Component

  @default_locale "en"

  def on_mount(:restore_locale, _params, session, socket) do
    locale = determine_locale(session, socket)

    Gettext.put_locale(KlassHeroWeb.Gettext, locale)

    {:cont, assign(socket, :locale, locale)}
  end

  defp determine_locale(session, socket) do
    cond do
      # 1. Check authenticated user preference (highest priority for logged-in users)
      user_locale = get_user_locale(socket) ->
        user_locale

      # 2. Fall back to session locale (set by plug)
      session_locale = Map.get(session, "locale") ->
        session_locale

      # 3. Default
      true ->
        @default_locale
    end
  end

  defp get_user_locale(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{locale: locale}}} when is_binary(locale) -> locale
      _ -> nil
    end
  end
end
