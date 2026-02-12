defmodule KlassHero.Accounts.Domain.Ports.ForStoringUsers do
  @moduledoc """
  Port for user persistence operations in the Accounts bounded context.

  Defines the contract for user read and write operations without exposing
  infrastructure details. Write callbacks use `term()` return types to keep
  the port Ecto-free — the repository pragmatically returns Ecto schemas
  that callers (LiveViews, auth plugs) already expect.

  Infrastructure errors (connection, query) are not caught — they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Accounts.Domain.Models.User

  # ============================================================================
  # Read operations
  # ============================================================================

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
  - `{:error, :not_found}` - No user with this email
  """
  @callback get_by_email(String.t()) :: {:ok, User.t()} | {:error, :not_found}

  @doc """
  Checks if a user exists with the given ID.
  """
  @callback exists?(binary()) :: boolean()

  # ============================================================================
  # Write operations
  # ============================================================================

  @doc """
  Registers a new user from the given attributes.

  Returns:
  - `{:ok, term()}` - User created (Ecto schema)
  - `{:error, term()}` - Validation or persistence failure (Ecto changeset)
  """
  @callback register(map()) :: {:ok, term()} | {:error, term()}

  @doc """
  Anonymizes a user's PII and deletes all their tokens atomically.

  Returns:
  - `{:ok, term()}` - Anonymized user (Ecto schema)
  - `{:error, term()}` - Update failure
  """
  @callback anonymize(term()) :: {:ok, term()} | {:error, term()}

  @doc """
  Applies an email change using a confirmation token.

  Verifies the token, updates the email, and deletes all change tokens
  for the context atomically.

  Returns:
  - `{:ok, term()}` - Updated user (Ecto schema)
  - `{:error, :invalid_token}` - Token malformed, expired, or not found
  - `{:error, term()}` - Update failure
  """
  @callback apply_email_change(term(), binary()) ::
              {:ok, term()} | {:error, :invalid_token | term()}

  @doc """
  Resolves a magic link token to a user and determines login scenario.

  Returns tagged tuples to distinguish business cases:
  - `{:ok, {:confirmed, user, token}}` - Already-confirmed user, token to delete
  - `{:ok, {:unconfirmed, user}}` - Unconfirmed user needing confirmation
  - `{:error, :not_found}` - Token invalid or expired
  - `{:error, :invalid_token}` - Token malformed (bad base64)
  - `{:error, :security_violation}` - Unconfirmed user with password set
  """
  @callback resolve_magic_link(binary()) ::
              {:ok, {:confirmed, term(), term()} | {:unconfirmed, term()}}
              | {:error, :not_found | :invalid_token | :security_violation}

  @doc """
  Confirms a user and deletes all their tokens atomically.

  Used after resolving a magic link for an unconfirmed user.

  Returns:
  - `{:ok, {term(), list()}}` - Confirmed user + deleted tokens
  - `{:error, term()}` - Update failure
  """
  @callback confirm_and_cleanup_tokens(term()) ::
              {:ok, {term(), list()}} | {:error, term()}

  @doc """
  Deletes a single token record.

  Used to expire a magic link token after successful login for confirmed users.

  Returns:
  - `:ok` - Token deleted (or already gone)
  - `{:error, term()}` - Deletion failure
  """
  @callback delete_token(term()) :: :ok | {:error, term()}
end
