defmodule KlassHero.Community do
  @moduledoc """
  Public API for the Community bounded context.

  Manages community posts, comments, and likes.
  """

  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Shared],
    exports: [
      Application.UseCases.AddComment,
      Application.UseCases.ListPosts,
      Application.UseCases.ToggleLike,
      Adapters.Driven.Events.EventHandlers.NotifyLiveViews
    ]
end
