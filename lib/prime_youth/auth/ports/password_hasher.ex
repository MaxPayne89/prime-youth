defmodule PrimeYouth.Auth.Ports.PasswordHasher do
  @moduledoc """
  Secondary port: the application needs this for password hashing and verification.
  Infrastructure provides the actual implementation (typically bcrypt-based).
  """

  @callback hash(String.t()) :: {:ok, String.t()} | {:error, term()}
  @callback verify(String.t(), String.t()) :: boolean()
end
