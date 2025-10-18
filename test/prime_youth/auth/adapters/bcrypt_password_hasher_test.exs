defmodule PrimeYouth.Auth.Adapters.Driven.PasswordHashing.BcryptPasswordHasherTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.Auth.Adapters.Driven.PasswordHashing.BcryptPasswordHasher

  describe "hash/1" do
    test "hashes a password" do
      password = "my_secure_password"

      assert {:ok, hashed} = BcryptPasswordHasher.hash(password)
      assert is_binary(hashed)
      assert hashed != password
      assert String.starts_with?(hashed, "$2b$")
    end

    test "generates different hashes for same password" do
      password = "my_secure_password"

      assert {:ok, hash1} = BcryptPasswordHasher.hash(password)
      assert {:ok, hash2} = BcryptPasswordHasher.hash(password)
      assert hash1 != hash2
    end
  end

  describe "verify/2" do
    test "verifies a correct password" do
      password = "my_secure_password"
      {:ok, hashed} = BcryptPasswordHasher.hash(password)

      assert BcryptPasswordHasher.verify(password, hashed) == true
    end

    test "rejects an incorrect password" do
      password = "my_secure_password"
      {:ok, hashed} = BcryptPasswordHasher.hash(password)

      assert BcryptPasswordHasher.verify("wrong_password", hashed) == false
    end

    test "returns false when password is nil" do
      {:ok, hashed} = BcryptPasswordHasher.hash("password123456")

      assert BcryptPasswordHasher.verify(nil, hashed) == false
    end

    test "returns false when hash is nil" do
      assert BcryptPasswordHasher.verify("password", nil) == false
    end

    test "returns false when hash is invalid format" do
      assert BcryptPasswordHasher.verify("password", "not_a_valid_hash") == false
    end
  end
end
