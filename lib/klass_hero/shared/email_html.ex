defmodule KlassHero.Shared.EmailHtml do
  @moduledoc """
  Shared scaffolding for transactional email HTML bodies.

  Centralises the KlassHero brand bar, typography defaults, and footer so
  all notifiers render with one consistent shell. Each notifier supplies
  the inner content; this module wraps it.
  """

  @default_footer "If you didn't expect this email, you can safely ignore it."

  @doc "HTML-escapes any term, coercing to string first."
  @spec esc(term()) :: String.t()
  def esc(text) do
    text
    |> to_string()
    |> escape_chars(<<>>)
  end

  defp escape_chars(<<>>, acc), do: acc
  defp escape_chars(<<"<", rest::binary>>, acc), do: escape_chars(rest, acc <> "&lt;")
  defp escape_chars(<<">", rest::binary>>, acc), do: escape_chars(rest, acc <> "&gt;")
  defp escape_chars(<<"&", rest::binary>>, acc), do: escape_chars(rest, acc <> "&amp;")
  defp escape_chars(<<"\"", rest::binary>>, acc), do: escape_chars(rest, acc <> "&quot;")
  defp escape_chars(<<"'", rest::binary>>, acc), do: escape_chars(rest, acc <> "&#39;")
  defp escape_chars(<<c::utf8, rest::binary>>, acc), do: escape_chars(rest, acc <> <<c::utf8>>)

  @doc """
  Wraps a pre-rendered HTML string in the standard KlassHero email shell.

  `inner_html` must be a binary — callers build it via `~s|...|` or heredoc strings.

  ## Options

    * `:footer_message` — overrides the default footer paragraph.
  """
  @spec wrap(String.t(), keyword()) :: String.t()
  def wrap(inner_html, opts \\ []) when is_binary(inner_html) do
    footer = Keyword.get(opts, :footer_message, @default_footer) |> esc()

    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #333;">
      <div style="text-align: center; padding: 20px 0; border-bottom: 2px solid #4F46E5;">
        <h1 style="color: #4F46E5; margin: 0; font-size: 24px;">KlassHero</h1>
      </div>
      <div style="padding: 30px 0;">
    #{inner_html}
      </div>
      <div style="border-top: 1px solid #eee; padding-top: 15px; color: #999; font-size: 12px;">
        <p>#{footer}</p>
      </div>
    </body>
    </html>
    """
  end
end
