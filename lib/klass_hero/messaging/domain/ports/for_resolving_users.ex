defmodule KlassHero.Messaging.Domain.Ports.ForResolvingUsers do
  @moduledoc """
  Port for resolving user display information in the Messaging bounded context.

  This behaviour defines the contract for querying user data from the
  Accounts context. Implemented by adapters in the infrastructure layer.
  """

  @doc """
  Gets display names for a list of user IDs.

  Returns a map of user_id => display_name for all found users.
  Users not found are omitted from the result.

  ## Parameters
  - user_ids: List of user IDs to resolve

  ## Returns
  - `{:ok, %{user_id => name}}` - Map of user IDs to display names
  """
  @callback get_display_names(user_ids :: [String.t()]) :: {:ok, %{String.t() => String.t()}}

  @doc """
  Gets the display name for a single user.

  Returns the user's name or a fallback if not found.

  ## Parameters
  - user_id: The user ID to resolve

  ## Returns
  - `{:ok, name}` - User's display name
  - `{:error, :not_found}` - User not found
  """
  @callback get_display_name(user_id :: String.t()) ::
              {:ok, String.t()} | {:error, :not_found}

  @doc """
  Gets the user ID (identity_id) for a provider profile.

  Used to resolve the provider_id stored on conversations (which is the
  provider profile ID) back to the user ID for permission checks.

  ## Parameters
  - provider_id: The provider profile ID

  ## Returns
  - `{:ok, user_id}` - The user ID for this provider
  - `{:error, :not_found}` - No provider exists with this ID
  """
  @callback get_user_id_for_provider(provider_id :: String.t()) ::
              {:ok, String.t()} | {:error, :not_found}
end
