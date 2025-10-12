defmodule PrimeYouth.Auth.Adapters.Driven.BcryptPasswordHasher do
  @moduledoc """
  Adapter implementing PasswordHasher port using Bcrypt.
  Wraps the Bcrypt library for password hashing and verification.
  """

  @behaviour PrimeYouth.Auth.Ports.PasswordHasher

  @impl true
  def hash(password) when is_binary(password) do
    {:ok, Bcrypt.hash_pwd_salt(password)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def verify(password, hashed_password) when is_binary(password) and is_binary(hashed_password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def verify(_, _), do: false
end
