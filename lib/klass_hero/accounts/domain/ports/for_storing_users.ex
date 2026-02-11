defmodule KlassHero.Accounts.Domain.Ports.ForStoringUsers do
  @moduledoc """
  Port for user persistence operations in the Accounts bounded context.

  Defines the contract for retrieving users without exposing infrastructure
  details. Read-only operations that return domain models.

  Infrastructure errors (connection, query) are not caught — they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Accounts.Domain.Models.User

  @doc """
  Retrieves a user by their unique identifier.

  Returns:
  - `{:ok, User.t()}` - User found
  - `{:error, :not_found}` - No user with this ID
  """
  @callback get_by_id(binary()) :: {:ok, User.t()} | {:error, :not_found}

  @doc """
  Retrieves a user by email address.

  Returns:
  - `{:ok, User.t()}` - User found
  - `nil` - No user with this email
  """
  @callback get_by_email(String.t()) :: {:ok, User.t()} | nil

  @doc """
  Checks if a user exists with the given ID.
  """
  @callback exists?(binary()) :: boolean()
end
