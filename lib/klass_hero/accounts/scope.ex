defmodule KlassHero.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `KlassHero.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias KlassHero.Accounts.User
  alias KlassHero.Identity

  defstruct user: nil,
            roles: [],
            parent: nil,
            provider: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Resolves roles for the scope by checking profile existence in both contexts.

  Updates the scope with:
  - roles: list of active roles (["parent", "provider"])
  - parent: parent profile if exists
  - provider: provider profile if exists

  Returns the updated scope.
  """
  def resolve_roles(%__MODULE__{user: nil} = scope), do: scope

  def resolve_roles(%__MODULE__{user: user} = scope) do
    parent = extract_profile(Identity.get_parent_by_identity(user.id))
    provider = extract_profile(Identity.get_provider_by_identity(user.id))

    roles =
      []
      |> maybe_add_role(parent, :parent)
      |> maybe_add_role(provider, :provider)

    %{scope | roles: roles, parent: parent, provider: provider}
  end

  @doc """
  Checks if the scope has a specific role.

  ## Examples

      iex> has_role?(scope, :parent)
      true

      iex> has_role?(scope, :provider)
      false
  """
  def has_role?(%__MODULE__{roles: roles}, role) when is_atom(role) do
    role in roles
  end

  @doc """
  Returns true if the scope has a parent profile.

  ## Examples

      iex> parent?(scope)
      true
  """
  def parent?(%__MODULE__{parent: parent}), do: parent != nil

  @doc """
  Returns true if the scope has a provider profile.

  ## Examples

      iex> provider?(scope)
      true
  """
  def provider?(%__MODULE__{provider: provider}), do: provider != nil

  # Private helpers

  defp extract_profile({:ok, profile}), do: profile
  defp extract_profile({:error, _}), do: nil

  defp maybe_add_role(roles, nil, _role), do: roles
  defp maybe_add_role(roles, _profile, role), do: [role | roles]
end
