defmodule PrimeYouthWeb.Plugs.SetLocale do
  @moduledoc """
  Plug for detecting and setting the user's locale preference.

  Locale is determined by priority:
  1. Query parameter `?locale=de` (for testing/sharing)
  2. Session stored locale
  3. Authenticated user's database preference
  4. Browser Accept-Language header
  5. Default: "en"

  The locale is stored in session and assigned to conn for use by LiveView hooks.
  """

  @behaviour Plug

  import Plug.Conn

  @supported_locales ~w(en de)
  @default_locale "en"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    locale = detect_locale(conn)

    Gettext.put_locale(PrimeYouthWeb.Gettext, locale)

    conn
    |> assign(:locale, locale)
    |> put_session(:locale, locale)
  end

  defp detect_locale(conn) do
    [
      &query_param_locale/1,
      &session_locale/1,
      &user_locale/1,
      &accept_language_locale/1,
      fn _ -> @default_locale end
    ]
    |> Enum.find_value(fn detector -> detector.(conn) end)
    |> validate_locale()
  end

  defp query_param_locale(%{params: %{"locale" => locale}}), do: locale
  defp query_param_locale(_conn), do: nil

  defp session_locale(conn), do: get_session(conn, :locale)

  defp user_locale(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{locale: locale}} when is_binary(locale) -> locale
      _ -> nil
    end
  end

  defp accept_language_locale(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> parse_accept_language()
  end

  defp parse_accept_language(nil), do: nil

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&extract_language_code/1)
    |> Enum.find(&(&1 in @supported_locales))
  end

  defp extract_language_code(lang_entry) do
    lang_entry
    |> String.split(";")
    |> List.first()
    |> String.split("-")
    |> List.first()
    |> String.downcase()
  end

  defp validate_locale(locale) when locale in @supported_locales, do: locale
  defp validate_locale(_), do: @default_locale
end
