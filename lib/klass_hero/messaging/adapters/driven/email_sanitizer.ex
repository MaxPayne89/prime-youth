defmodule KlassHero.Messaging.Adapters.Driven.EmailSanitizer do
  @moduledoc """
  Sanitizes inbound email HTML for safe rendering in the admin panel.

  Wraps `HtmlSanitizeEx.basic_html/1` (which strips dangerous tags and event
  handler attributes), then applies email-specific post-processing:
  - Blocks external images by default to prevent tracking pixels
  - Adds `target="_blank"` and `rel="noopener noreferrer"` to all links
  """

  @spec sanitize(String.t() | nil) :: String.t()
  # Separate arity to avoid a duplicate-default compile error when both
  # `sanitize/1` and `sanitize/2` would otherwise share `opts \\ []`.
  def sanitize(html), do: sanitize(html, [])

  @spec sanitize(String.t() | nil, keyword()) :: String.t()
  def sanitize(nil, _opts), do: ""
  def sanitize("", _opts), do: ""

  def sanitize(html, opts) when is_binary(html) do
    allow_images = Keyword.get(opts, :allow_images, false)

    html
    # Trigger: raw user-supplied HTML from an inbound email
    # Why: strip dangerous tags (script, iframe, style) and all event-handler
    #      attributes (onclick, onerror, etc.) before we touch it further
    # Outcome: only allowlisted tags and attributes survive
    |> HtmlSanitizeEx.basic_html()
    |> post_process_links()
    |> maybe_block_images(allow_images)
  end

  # Adds safe link-opening attributes to every anchor tag so that clicking
  # a link in a received email opens a new tab and cannot manipulate the
  # opener window (tabnabbing prevention).
  defp post_process_links(html) do
    # Trigger: any <a …> tag in sanitized output
    # Why: emails frequently contain links; opening them in the same tab would
    #      navigate away from the admin panel; `noopener noreferrer` prevents
    #      the opened page from accessing `window.opener`
    # Outcome: all links open in a new tab with no opener reference
    String.replace(html, ~r/<a\b/i, ~s(<a target="_blank" rel="noopener noreferrer"))
  end

  # Trigger: `allow_images: false` (the default)
  # Why: external images are a classic email-tracking vector (tracking pixels);
  #      blocking them by default protects user privacy
  # Outcome: all <img> tags referencing http/https URLs are replaced with a
  #          "[image blocked]" placeholder
  defp maybe_block_images(html, false) do
    String.replace(html, ~r/<img\b[^>]*src="https?:\/\/[^"]*"[^>]*\/?>/i, "[image blocked]")
  end

  # Trigger: `allow_images: true` passed by caller
  # Why: some views (e.g. a full message preview) intentionally show images
  # Outcome: <img> tags are left as-is by `basic_html`
  defp maybe_block_images(html, true), do: html
end
