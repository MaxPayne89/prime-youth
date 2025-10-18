defmodule PrimeYouth.Auth.Adapters.Driven.Persistence.Mappers.UserMapper do
  @moduledoc """
  Maps between domain User model and Ecto UserSchema.
  Handles bidirectional conversion for data persistence.
  """

  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserSchema
  alias PrimeYouth.Auth.Domain.Models.User

  @doc """
  Converts domain User to Ecto schema for database operations.
  """
  def to_schema(%User{} = user) do
    %UserSchema{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      hashed_password: user.hashed_password,
      confirmed_at: user.confirmed_at
    }
  end

  @doc """
  Converts Ecto schema to domain User.
  """
  def to_domain(%UserSchema{} = schema) do
    %User{
      id: schema.id,
      email: schema.email,
      first_name: schema.first_name,
      last_name: schema.last_name,
      hashed_password: schema.hashed_password,
      confirmed_at: schema.confirmed_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
