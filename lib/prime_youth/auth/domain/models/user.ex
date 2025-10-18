defmodule PrimeYouth.Auth.Domain.Models.User do
  @moduledoc """
  Domain entity representing a user in the authentication context.
  Contains pure domain logic and business rules for user management.
  """

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          hashed_password: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          authenticated_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:email]
  defstruct [
    :id,
    :email,
    :first_name,
    :last_name,
    :hashed_password,
    :confirmed_at,
    :authenticated_at,
    :inserted_at,
    :updated_at
  ]

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @doc """
  Creates a new user domain entity with validation.
  """
  def new(attrs) do
    with {:ok, email} <- validate_email(attrs[:email]),
         {:ok, first_name} <- validate_name(attrs[:first_name], :first_name),
         {:ok, last_name} <- validate_name(attrs[:last_name], :last_name) do
      {:ok, %__MODULE__{email: email, first_name: first_name, last_name: last_name}}
    end
  end

  @doc """
  Confirms the user account by setting the confirmed_at timestamp.
  """
  def confirm(%__MODULE__{} = user, confirmed_at) do
    %{user | confirmed_at: confirmed_at}
  end

  @doc """
  Marks the user as authenticated by setting the authenticated_at timestamp.
  This should be called whenever a user successfully authenticates (login, magic link, etc.)
  """
  def authenticate(%__MODULE__{} = user, authenticated_at) do
    %{user | authenticated_at: authenticated_at}
  end

  @doc """
  Updates the user's email address with validation.
  """
  def update_email(%__MODULE__{} = user, new_email) do
    with {:ok, validated_email} <- validate_email(new_email) do
      {:ok, %{user | email: validated_email, confirmed_at: nil}}
    end
  end

  @doc """
  Validates whether the user is confirmed.
  """
  def confirmed?(%__MODULE__{confirmed_at: nil}), do: false
  def confirmed?(%__MODULE__{confirmed_at: _}), do: true

  @doc """
  Validates an email address according to domain rules.
  """
  def validate_email(nil), do: {:error, :email_required}
  def validate_email(""), do: {:error, :email_required}

  def validate_email(email) when is_binary(email) do
    email = String.trim(email)

    cond do
      String.length(email) > 160 ->
        {:error, :email_too_long}

      not Regex.match?(@email_regex, email) ->
        {:error, :invalid_email_format}

      true ->
        {:ok, String.downcase(email)}
    end
  end

  def validate_email(_), do: {:error, :invalid_email_format}

  @doc """
  Validates a name field (first_name or last_name) according to domain rules.
  """
  def validate_name(nil, field), do: {:error, :"#{field}_required"}
  def validate_name("", field), do: {:error, :"#{field}_required"}

  def validate_name(name, _field) when is_binary(name) do
    name = String.trim(name)

    cond do
      String.length(name) == 0 ->
        {:error, :name_required}

      String.length(name) > 100 ->
        {:error, :name_too_long}

      true ->
        {:ok, name}
    end
  end

  def validate_name(_, field), do: {:error, :"invalid_#{field}"}
end
