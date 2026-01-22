defmodule KlassHeroWeb.Helpers.IdentityHelpers do
  @moduledoc """
  Shared helpers for working with identity data in LiveViews.
  """

  alias KlassHero.Identity

  @doc """
  Retrieves children for the current user from socket assigns.

  Returns empty list if no parent profile exists.
  """
  def get_children_for_current_user(socket) do
    with %{current_scope: %{user: %{id: identity_id}}} <- socket.assigns,
         {:ok, parent} <- Identity.get_parent_by_identity(identity_id) do
      Identity.get_children(parent.id)
    else
      _ -> []
    end
  end
end
