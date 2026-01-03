defmodule KlassHero.Shared.Adapters.Driven.Persistence.EctoErrorHelpersTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Persistence.EctoErrorHelpers

  describe "unique_constraint_violation?/2" do
    test "returns true when unique constraint violation exists for specified field" do
      errors = [{:identity_id, {"has already been taken", [constraint: :unique]}}]

      assert EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id)
    end

    test "returns true when unique constraint violation exists among multiple errors" do
      errors = [
        {:email, {"is invalid", []}},
        {:identity_id, {"has already been taken", [constraint: :unique]}},
        {:name, {"can't be blank", []}}
      ]

      assert EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id)
    end

    test "returns false when no constraint violation exists for field" do
      errors = [{:identity_id, {"is invalid", []}}]

      refute EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id)
    end

    test "returns false when constraint violation is for different field" do
      errors = [{:email, {"has already been taken", [constraint: :unique]}}]

      refute EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id)
    end

    test "returns false when constraint type is different" do
      errors = [{:identity_id, {"does not exist", [constraint: :foreign]}}]

      refute EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id)
    end

    test "returns false for empty error list" do
      errors = []

      refute EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id)
    end

    test "handles multiple constraint violations correctly" do
      errors = [
        {:email, {"has already been taken", [constraint: :unique]}},
        {:identity_id, {"has already been taken", [constraint: :unique]}}
      ]

      assert EctoErrorHelpers.unique_constraint_violation?(errors, :email)
      assert EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id)
    end
  end

  describe "foreign_key_violation?/2" do
    test "returns true when foreign key constraint violation exists for specified field" do
      errors = [{:user_id, {"does not exist", [constraint: :foreign]}}]

      assert EctoErrorHelpers.foreign_key_violation?(errors, :user_id)
    end

    test "returns true when foreign key violation exists among multiple errors" do
      errors = [
        {:email, {"is invalid", []}},
        {:user_id, {"does not exist", [constraint: :foreign]}},
        {:name, {"can't be blank", []}}
      ]

      assert EctoErrorHelpers.foreign_key_violation?(errors, :user_id)
    end

    test "returns false when no constraint violation exists for field" do
      errors = [{:user_id, {"is invalid", []}}]

      refute EctoErrorHelpers.foreign_key_violation?(errors, :user_id)
    end

    test "returns false when constraint violation is for different field" do
      errors = [{:organization_id, {"does not exist", [constraint: :foreign]}}]

      refute EctoErrorHelpers.foreign_key_violation?(errors, :user_id)
    end

    test "returns false when constraint type is different" do
      errors = [{:user_id, {"has already been taken", [constraint: :unique]}}]

      refute EctoErrorHelpers.foreign_key_violation?(errors, :user_id)
    end

    test "returns false for empty error list" do
      errors = []

      refute EctoErrorHelpers.foreign_key_violation?(errors, :user_id)
    end
  end

  describe "constraint_violation?/3" do
    test "detects unique constraint violations" do
      errors = [{:email, {"has already been taken", [constraint: :unique]}}]

      assert EctoErrorHelpers.constraint_violation?(errors, :email, :unique)
    end

    test "detects foreign key constraint violations" do
      errors = [{:user_id, {"does not exist", [constraint: :foreign]}}]

      assert EctoErrorHelpers.constraint_violation?(errors, :user_id, :foreign)
    end

    test "detects check constraint violations" do
      errors = [{:age, {"must be greater than 0", [constraint: :check]}}]

      assert EctoErrorHelpers.constraint_violation?(errors, :age, :check)
    end

    test "returns false when field matches but constraint type differs" do
      errors = [{:email, {"has already been taken", [constraint: :unique]}}]

      refute EctoErrorHelpers.constraint_violation?(errors, :email, :foreign)
    end

    test "returns false when constraint type matches but field differs" do
      errors = [{:email, {"has already been taken", [constraint: :unique]}}]

      refute EctoErrorHelpers.constraint_violation?(errors, :username, :unique)
    end

    test "returns false when error has no constraint option" do
      errors = [{:email, {"is invalid", []}}]

      refute EctoErrorHelpers.constraint_violation?(errors, :email, :unique)
    end

    test "returns false for empty error list" do
      errors = []

      refute EctoErrorHelpers.constraint_violation?(errors, :email, :unique)
    end

    test "finds constraint violation among multiple errors" do
      errors = [
        {:name, {"can't be blank", []}},
        {:email, {"is invalid", []}},
        {:identity_id, {"has already been taken", [constraint: :unique]}},
        {:age, {"must be a number", []}}
      ]

      assert EctoErrorHelpers.constraint_violation?(errors, :identity_id, :unique)
      refute EctoErrorHelpers.constraint_violation?(errors, :name, :unique)
      refute EctoErrorHelpers.constraint_violation?(errors, :email, :unique)
    end
  end
end
