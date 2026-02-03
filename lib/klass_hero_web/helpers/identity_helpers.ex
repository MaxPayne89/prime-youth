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
      # Trigger: no user in scope (anonymous) or no parent profile
      # Why: normal states, not errors
      # Outcome: empty list — UI shows "no children" state
      %{} -> []
      {:error, :not_found} -> []
    end
  end

  @doc """
  Retrieves the parent profile for the current user from socket assigns.

  Returns:
  - `{:ok, parent}` if parent profile exists
  - `{:error, :no_parent}` if no parent profile or no user in scope
  """
  def get_parent_for_current_user(socket) do
    with %{current_scope: %{user: %{id: identity_id}}} <- socket.assigns,
         {:ok, parent} <- Identity.get_parent_by_identity(identity_id) do
      {:ok, parent}
    else
      # Trigger: no user in scope (anonymous) or no parent profile
      # Why: normal states, not errors
      # Outcome: caller handles :no_parent appropriately
      %{} -> {:error, :no_parent}
      {:error, :not_found} -> {:error, :no_parent}
    end
  end
end
