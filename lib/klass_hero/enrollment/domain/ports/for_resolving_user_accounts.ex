defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingUserAccounts do
  @moduledoc """
  Port for resolving user accounts in the Enrollment bounded context.

  Decouples the Enrollment context from the Accounts implementation by
  providing a boundary-safe contract for user lookup and registration.
  Adapters map Accounts structs to lightweight maps so no Accounts
  domain types leak into Enrollment.
  """

  @type user_result :: %{id: String.t(), email: String.t(), name: String.t()}

  @doc """
  Looks up a user by email address.

  Returns a lightweight user map if found, `nil` otherwise.
  """
  @callback get_user_by_email(email :: String.t()) :: user_result() | nil

  @doc """
  Registers a new user account from the given attributes.

  Returns `{:ok, user_result()}` on success or `{:error, term()}` on failure.
  """
  @callback register_user(attrs :: map()) :: {:ok, user_result()} | {:error, term()}
end
