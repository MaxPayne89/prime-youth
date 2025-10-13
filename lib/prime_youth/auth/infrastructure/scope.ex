defmodule PrimeYouth.Auth.Infrastructure.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `PrimeYouth.Auth.Infrastructure.Scope` allows public interfaces to receive
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

  alias PrimeYouth.Auth.Domain.User, as: DomainUser
  alias PrimeYouth.Auth.Infrastructure.User

  defstruct user: nil

  @doc """
  Creates a scope for the given user.

  Accepts both domain users and schema users, converting domain users to schema users.
  Returns nil if no user is given.
  """
  def for_user(%DomainUser{} = domain_user) do
    # Convert domain user to schema user for scope, preserving virtual fields
    schema_user = %User{
      id: domain_user.id,
      email: domain_user.email,
      first_name: domain_user.first_name,
      last_name: domain_user.last_name,
      hashed_password: domain_user.hashed_password,
      confirmed_at: domain_user.confirmed_at,
      authenticated_at: domain_user.authenticated_at,
      inserted_at: domain_user.inserted_at,
      updated_at: domain_user.updated_at
    }

    %__MODULE__{user: schema_user}
  end

  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
