defmodule PrimeYouth.Community.Domain.Models.Post do
  @moduledoc """
  Domain entity representing a social post in the Community feed.

  A post contains author information, content, engagement metrics (likes, comments),
  and optional type-specific data (photos, events).
  """

  alias PrimeYouth.Community.Domain.Models.Comment

  @enforce_keys [
    :id,
    :author,
    :avatar_bg,
    :avatar_emoji,
    :timestamp,
    :content,
    :type,
    :likes,
    :comment_count,
    :user_liked,
    :comments
  ]
  defstruct [
    :id,
    :author,
    :avatar_bg,
    :avatar_emoji,
    :timestamp,
    :content,
    :type,
    :photo_emoji,
    :event_details,
    :likes,
    :comment_count,
    :user_liked,
    comments: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          author: String.t(),
          avatar_bg: String.t(),
          avatar_emoji: String.t(),
          timestamp: String.t(),
          content: String.t(),
          type: :photo | :text | :event,
          photo_emoji: String.t() | nil,
          event_details: map() | nil,
          likes: non_neg_integer(),
          comment_count: non_neg_integer(),
          user_liked: boolean(),
          comments: [Comment.t()]
        }
end
