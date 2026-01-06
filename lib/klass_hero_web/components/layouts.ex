defmodule KlassHeroWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use KlassHeroWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides language switcher for German/English localization.

  Renders buttons that switch the locale by navigating with a query parameter.
  The current locale is highlighted with a different style.

  ## Examples

      <.language_switcher locale={@locale} />
  """
  attr :locale, :string, default: "en", doc: "Current locale (en or de)"

  def language_switcher(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class={[
        "absolute w-1/2 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 transition-[left]",
        if(@locale == "en", do: "left-0", else: "left-1/2")
      ]} />

      <.link
        href="?locale=en"
        class={[
          "flex items-center gap-1 px-3 py-2 cursor-pointer w-1/2 text-sm font-medium z-10",
          if(@locale == "en", do: "opacity-100", else: "opacity-60 hover:opacity-100")
        ]}
      >
        <span class="text-base">🇬🇧</span>
        <span class="hidden sm:inline">EN</span>
      </.link>

      <.link
        href="?locale=de"
        class={[
          "flex items-center gap-1 px-3 py-2 cursor-pointer w-1/2 text-sm font-medium z-10",
          if(@locale == "de", do: "opacity-100", else: "opacity-60 hover:opacity-100")
        ]}
      >
        <span class="text-base">🇩🇪</span>
        <span class="hidden sm:inline">DE</span>
      </.link>
    </div>
    """
  end
end
