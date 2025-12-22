defmodule PrimeYouth.Accounts.Types.UserRolesTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.Accounts.Types.UserRoles

  describe "type/0" do
    test "returns :array of :string" do
      assert UserRoles.type() == {:array, :string}
    end
  end

  describe "cast/1" do
    test "casts list of valid atom roles" do
      assert UserRoles.cast([:parent]) == {:ok, [:parent]}
      assert UserRoles.cast([:provider]) == {:ok, [:provider]}
      assert UserRoles.cast([:parent, :provider]) == {:ok, [:parent, :provider]}
    end

    test "casts list of valid string roles to atoms" do
      assert UserRoles.cast(["parent"]) == {:ok, [:parent]}
      assert UserRoles.cast(["provider"]) == {:ok, [:provider]}
      assert UserRoles.cast(["parent", "provider"]) == {:ok, [:parent, :provider]}
    end

    test "casts mixed list of strings and atoms" do
      assert UserRoles.cast([:parent, "provider"]) == {:ok, [:parent, :provider]}
      assert UserRoles.cast(["parent", :provider]) == {:ok, [:parent, :provider]}
    end

    test "deduplicates roles" do
      assert UserRoles.cast([:parent, :parent]) == {:ok, [:parent]}
      assert UserRoles.cast(["parent", "parent"]) == {:ok, [:parent]}
      assert UserRoles.cast([:parent, "parent"]) == {:ok, [:parent]}
      assert UserRoles.cast([:parent, :provider, :parent]) == {:ok, [:parent, :provider]}
    end

    test "preserves role order" do
      assert UserRoles.cast([:provider, :parent]) == {:ok, [:provider, :parent]}
      assert UserRoles.cast(["provider", "parent"]) == {:ok, [:provider, :parent]}
    end

    test "casts nil to empty list" do
      assert UserRoles.cast(nil) == {:ok, []}
    end

    test "casts empty list to empty list" do
      assert UserRoles.cast([]) == {:ok, []}
    end

    test "returns error for invalid atom role" do
      assert UserRoles.cast([:admin]) == :error
      assert UserRoles.cast([:parent, :admin]) == :error
    end

    test "returns error for invalid string role" do
      assert UserRoles.cast(["admin"]) == :error
      assert UserRoles.cast(["parent", "admin"]) == :error
    end

    test "returns error for non-list values" do
      assert UserRoles.cast("parent") == :error
      assert UserRoles.cast(:parent) == :error
      assert UserRoles.cast(123) == :error
      assert UserRoles.cast(%{}) == :error
    end

    test "returns error for list with invalid types" do
      assert UserRoles.cast([123]) == :error
      assert UserRoles.cast([nil]) == :error
      assert UserRoles.cast([:parent, 123]) == :error
    end
  end

  describe "load/1" do
    test "loads database strings to atom list" do
      assert UserRoles.load(["parent"]) == {:ok, [:parent]}
      assert UserRoles.load(["provider"]) == {:ok, [:provider]}
      assert UserRoles.load(["parent", "provider"]) == {:ok, [:parent, :provider]}
    end

    test "preserves order when loading" do
      assert UserRoles.load(["provider", "parent"]) == {:ok, [:provider, :parent]}
    end

    test "loads nil to empty list" do
      assert UserRoles.load(nil) == {:ok, []}
    end

    test "loads empty list to empty list" do
      assert UserRoles.load([]) == {:ok, []}
    end

    test "returns error for invalid string role" do
      assert UserRoles.load(["admin"]) == :error
      assert UserRoles.load(["parent", "admin"]) == :error
    end

    test "returns error for non-string values in list" do
      assert UserRoles.load([:parent]) == :error
      assert UserRoles.load([123]) == :error
      assert UserRoles.load([nil]) == :error
    end

    test "returns error for non-list values" do
      assert UserRoles.load("parent") == :error
      assert UserRoles.load(:parent) == :error
      assert UserRoles.load(123) == :error
    end
  end

  describe "dump/1" do
    test "dumps atom list to database strings" do
      assert UserRoles.dump([:parent]) == {:ok, ["parent"]}
      assert UserRoles.dump([:provider]) == {:ok, ["provider"]}
      assert UserRoles.dump([:parent, :provider]) == {:ok, ["parent", "provider"]}
    end

    test "preserves order when dumping" do
      assert UserRoles.dump([:provider, :parent]) == {:ok, ["provider", "parent"]}
    end

    test "dumps nil to empty list" do
      assert UserRoles.dump(nil) == {:ok, []}
    end

    test "dumps empty list to empty list" do
      assert UserRoles.dump([]) == {:ok, []}
    end

    test "returns error for invalid atom role" do
      assert UserRoles.dump([:admin]) == :error
      assert UserRoles.dump([:parent, :admin]) == :error
    end

    test "returns error for string values in list" do
      assert UserRoles.dump(["parent"]) == :error
    end

    test "returns error for non-list values" do
      assert UserRoles.dump("parent") == :error
      assert UserRoles.dump(:parent) == :error
      assert UserRoles.dump(123) == :error
    end
  end

  describe "embed_as/1" do
    test "returns :dump for event serialization" do
      assert UserRoles.embed_as(:any) == :dump
      assert UserRoles.embed_as(:self) == :dump
      assert UserRoles.embed_as(:dump) == :dump
      assert UserRoles.embed_as(nil) == :dump
    end
  end

  describe "round-trip conversion" do
    test "cast -> dump -> load maintains data integrity" do
      # Cast from strings (form input)
      {:ok, atoms} = UserRoles.cast(["parent", "provider"])
      assert atoms == [:parent, :provider]

      # Dump to database
      {:ok, strings} = UserRoles.dump(atoms)
      assert strings == ["parent", "provider"]

      # Load from database
      {:ok, loaded_atoms} = UserRoles.load(strings)
      assert loaded_atoms == [:parent, :provider]
    end

    test "handles edge cases through full round-trip" do
      # Empty list
      {:ok, atoms1} = UserRoles.cast([])
      {:ok, strings1} = UserRoles.dump(atoms1)
      {:ok, loaded1} = UserRoles.load(strings1)
      assert loaded1 == []

      # Single role
      {:ok, atoms2} = UserRoles.cast([:parent])
      {:ok, strings2} = UserRoles.dump(atoms2)
      {:ok, loaded2} = UserRoles.load(strings2)
      assert loaded2 == [:parent]

      # Nil handling
      {:ok, atoms3} = UserRoles.cast(nil)
      {:ok, strings3} = UserRoles.dump(atoms3)
      {:ok, loaded3} = UserRoles.load(strings3)
      assert loaded3 == []
    end
  end
end
