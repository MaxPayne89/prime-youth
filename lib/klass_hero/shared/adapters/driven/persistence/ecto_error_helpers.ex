defmodule KlassHero.Shared.Adapters.Driven.Persistence.EctoErrorHelpers do
  @moduledoc """
  Shared utilities for detecting and categorizing Ecto changeset errors.

  This module provides reusable functions for identifying specific types of database
  constraint violations and changeset errors across all repository implementations.

  ## Common Use Cases

  - Detecting unique constraint violations (duplicate records)
  - Detecting foreign key constraint violations (invalid references)
  - Categorizing errors for proper error handling and user feedback

  ## Examples

      # Detect unique constraint violation
      changeset = User.changeset(%User{}, %{email: "duplicate@example.com"})
      {:error, %Ecto.Changeset{errors: errors}} = Repo.insert(changeset)

      EctoErrorHelpers.unique_constraint_violation?(errors, :email)
      # => true

      # Detect foreign key violation
      changeset = Post.changeset(%Post{}, %{user_id: "non-existent"})
      {:error, %Ecto.Changeset{errors: errors}} = Repo.insert(changeset)

      EctoErrorHelpers.foreign_key_violation?(errors, :user_id)
      # => true

      # Check if any constraint violation exists
      EctoErrorHelpers.constraint_violation?(errors, :email, :unique)
      # => true
  """

  @doc """
  Detects if a specific field has a unique constraint violation.

  ## Parameters

  - `errors` - List of Ecto changeset errors in format `[{field, {message, opts}}]`
  - `field` - Atom representing the field name to check

  ## Returns

  - `true` if the field has a unique constraint violation
  - `false` otherwise

  ## Examples

      errors = [{:email, {"has already been taken", [constraint: :unique]}}]
      unique_constraint_violation?(errors, :email)
      # => true

      errors = [{:email, {"is invalid", []}}]
      unique_constraint_violation?(errors, :email)
      # => false

      errors = [{:identity_id, {"has already been taken", [constraint: :unique]}}]
      unique_constraint_violation?(errors, :identity_id)
      # => true
  """
  @spec unique_constraint_violation?(
          errors :: [{atom(), {String.t(), Keyword.t()}}],
          field :: atom()
        ) :: boolean()
  def unique_constraint_violation?(errors, field) when is_list(errors) and is_atom(field) do
    constraint_violation?(errors, field, :unique)
  end

  @doc """
  Detects if a specific field has a foreign key constraint violation.

  ## Parameters

  - `errors` - List of Ecto changeset errors in format `[{field, {message, opts}}]`
  - `field` - Atom representing the field name to check

  ## Returns

  - `true` if the field has a foreign key constraint violation
  - `false` otherwise

  ## Examples

      errors = [{:user_id, {"does not exist", [constraint: :foreign]}}]
      foreign_key_violation?(errors, :user_id)
      # => true

      errors = [{:user_id, {"is invalid", []}}]
      foreign_key_violation?(errors, :user_id)
      # => false
  """
  @spec foreign_key_violation?(
          errors :: [{atom(), {String.t(), Keyword.t()}}],
          field :: atom()
        ) :: boolean()
  def foreign_key_violation?(errors, field) when is_list(errors) and is_atom(field) do
    constraint_violation?(errors, field, :foreign)
  end

  @doc """
  Generic constraint violation detector.

  Checks if a specific field has a specific type of constraint violation.

  ## Parameters

  - `errors` - List of Ecto changeset errors in format `[{field, {message, opts}}]`
  - `field` - Atom representing the field name to check
  - `constraint_type` - Atom representing the constraint type (`:unique`, `:foreign`, etc.)

  ## Returns

  - `true` if the field has the specified constraint violation
  - `false` otherwise

  ## Examples

      errors = [{:email, {"has already been taken", [constraint: :unique]}}]
      constraint_violation?(errors, :email, :unique)
      # => true

      errors = [{:user_id, {"does not exist", [constraint: :foreign]}}]
      constraint_violation?(errors, :user_id, :foreign)
      # => true

      errors = [{:email, {"is invalid", []}}]
      constraint_violation?(errors, :email, :unique)
      # => false
  """
  @spec constraint_violation?(
          errors :: [{atom(), {String.t(), Keyword.t()}}],
          field :: atom(),
          constraint_type :: atom()
        ) :: boolean()
  def constraint_violation?(errors, field, constraint_type)
      when is_list(errors) and is_atom(field) and is_atom(constraint_type) do
    Enum.any?(errors, fn {error_field, {_message, opts}} ->
      error_field == field and Keyword.get(opts, :constraint) == constraint_type
    end)
  end
end
