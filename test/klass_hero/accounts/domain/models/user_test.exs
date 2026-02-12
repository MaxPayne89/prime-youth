defmodule KlassHero.Accounts.Domain.Models.UserTest do
  use ExUnit.Case, async: true

  alias KlassHero.Accounts.Domain.Models.User

  describe "new/1" do
    test "creates user with valid attrs" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        name: "Jane Doe",
        intended_roles: [:parent]
      }

      assert {:ok, %User{} = user} = User.new(attrs)
      assert user.email == "test@example.com"
      assert user.name == "Jane Doe"
      assert user.intended_roles == [:parent]
    end

    test "returns error when email is missing" do
      attrs = %{
        id: Ecto.UUID.generate(),
        name: "Jane Doe",
        intended_roles: [:parent]
      }

      assert {:error, errors} = User.new(attrs)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "Email"))
    end

    test "returns error when name is missing" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        intended_roles: [:parent]
      }

      assert {:error, errors} = User.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Name"))
    end

    test "returns error when email is empty" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "  ",
        name: "Jane Doe",
        intended_roles: [:parent]
      }

      assert {:error, errors} = User.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Email"))
    end

    test "returns error when id is nil" do
      attrs = %{id: nil, email: "test@example.com", name: "Jane"}

      assert {:error, errors} = User.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "ID"))
    end

    test "returns error when id is empty string" do
      attrs = %{id: "", email: "test@example.com", name: "Jane"}

      assert {:error, errors} = User.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "ID"))
    end

    test "returns error when id is zero" do
      attrs = %{id: 0, email: "test@example.com", name: "Jane"}

      assert {:error, errors} = User.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "ID"))
    end

    test "accepts positive integer id" do
      attrs = %{id: 42, email: "test@example.com", name: "Jane"}

      assert {:ok, %User{id: 42}} = User.new(attrs)
    end
  end

  describe "from_persistence/1" do
    test "reconstructs user from valid persistence data" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        name: "Jane Doe",
        intended_roles: [:parent],
        locale: "en",
        is_admin: false,
        confirmed_at: DateTime.utc_now(:second),
        inserted_at: DateTime.utc_now(:second),
        updated_at: DateTime.utc_now(:second)
      }

      assert {:ok, %User{}} = User.from_persistence(attrs)
    end

    test "returns error for missing required keys" do
      assert {:error, :invalid_persistence_data} = User.from_persistence(%{id: "123"})
    end
  end

  describe "anonymized_attrs/0" do
    test "returns canonical anonymization values" do
      attrs = User.anonymized_attrs()

      assert attrs.name == "Deleted User"
      assert attrs.avatar == nil
      assert is_function(attrs.email_fn, 1)
      assert attrs.email_fn.("abc-123") == "deleted_abc-123@anonymized.local"
    end
  end
end
