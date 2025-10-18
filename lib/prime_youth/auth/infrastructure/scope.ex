defmodule PrimeYouth.Auth.Infrastructure.Scope do
  @moduledoc """
  Scope struct used for scope-based authentication instead of direct user assignment.
  This allows for flexible authentication patterns and multi-tenant support.
  """

  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserSchema

  defstruct [:user]

  @type t :: %__MODULE__{
    user: UserSchema.t() | nil
  }

  @doc """
  Create a scope with the given user (schema, domain, or nil).
  """
  def for_user(nil), do: %__MODULE__{user: nil}
  def for_user(%UserSchema{} = user), do: %__MODULE__{user: user}
  def for_user(%PrimeYouth.Auth.Domain.Models.User{} = user) do
    # When we get a domain user, return nil scope since scope should contain schema user
    %__MODULE__{user: nil}
  end
end
