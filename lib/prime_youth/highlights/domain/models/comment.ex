defmodule PrimeYouth.Highlights.Domain.Models.Comment do
  @moduledoc """
  Value object representing a comment on a post.

  A comment consists of an author name and the text content of the comment.
  """

  @enforce_keys [:author, :text]
  defstruct [:author, :text]

  @type t :: %__MODULE__{
          author: String.t(),
          text: String.t()
        }
end
