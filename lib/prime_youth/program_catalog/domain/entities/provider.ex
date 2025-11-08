defmodule PrimeYouth.ProgramCatalog.Domain.Entities.Provider do
  @moduledoc """
  Provider domain entity representing an organization offering programs through the marketplace.

  This is a pure Elixir struct that encapsulates provider business logic without
  infrastructure concerns. Follows DDD principles with strong business rules validation.

  ## Business Rules

  - Each provider must be associated with a valid user account
  - Prime Youth provider (is_prime_youth=true) is unique and system-managed
  - External providers must be verified before programs can be approved
  - Provider cannot be deleted if they have active programs
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t() | nil,
          email: String.t(),
          phone: String.t() | nil,
          website: String.t() | nil,
          credentials: String.t() | nil,
          logo_url: String.t() | nil,
          is_verified: boolean(),
          is_prime_youth: boolean(),
          user_id: String.t(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:name, :email, :user_id]

  defstruct [
    :id,
    :name,
    :description,
    :email,
    :phone,
    :website,
    :credentials,
    :logo_url,
    :user_id,
    :created_at,
    :updated_at,
    is_verified: false,
    is_prime_youth: false
  ]

  @doc """
  Creates a new Provider entity with validation.

  ## Parameters

  - `attrs`: Map of provider attributes

  ## Returns

  - `{:ok, %Provider{}}` on success
  - `{:error, reason}` on validation failure

  ## Examples

      iex> Provider.new(%{
      ...>   name: "Test Provider",
      ...>   email: "test@provider.com",
      ...>   user_id: "uuid-here"
      ...> })
      {:ok, %Provider{}}

      iex> Provider.new(%{name: "AB", email: "test@provider.com", user_id: "uuid"})
      {:error, :invalid_name}
  """
  def new(attrs) when is_map(attrs) do
    with :ok <- validate_name(attrs[:name]),
         :ok <- validate_email(attrs[:email]),
         :ok <- validate_user_id(attrs[:user_id]),
         :ok <- validate_description(attrs[:description]),
         :ok <- validate_website(attrs[:website]),
         :ok <- validate_credentials(attrs[:credentials]) do
      provider = struct(__MODULE__, attrs)
      {:ok, provider}
    end
  end

  @doc """
  Creates a new Provider entity, raising on validation errors.

  ## Examples

      iex> Provider.new!(%{
      ...>   name: "Test Provider",
      ...>   email: "test@provider.com",
      ...>   user_id: "uuid-here"
      ...> })
      %Provider{}
  """
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, provider} -> provider
      {:error, reason} -> raise ArgumentError, "Invalid provider: #{reason}"
    end
  end

  # Private validation functions

  defp validate_name(nil), do: {:error, :name_required}

  defp validate_name(name) when is_binary(name) do
    length = String.length(name)

    cond do
      length < 2 -> {:error, :invalid_name}
      length > 200 -> {:error, :invalid_name}
      true -> :ok
    end
  end

  defp validate_name(_), do: {:error, :invalid_name}

  defp validate_email(nil), do: {:error, :email_required}

  defp validate_email(email) when is_binary(email) do
    if String.contains?(email, "@") and String.length(email) > 3 do
      :ok
    else
      {:error, :invalid_email}
    end
  end

  defp validate_email(_), do: {:error, :invalid_email}

  defp validate_user_id(nil), do: {:error, :user_id_required}
  defp validate_user_id(user_id) when is_binary(user_id) and byte_size(user_id) > 0, do: :ok
  defp validate_user_id(_), do: {:error, :invalid_user_id}

  defp validate_description(nil), do: :ok

  defp validate_description(description) when is_binary(description) do
    if String.length(description) <= 2000 do
      :ok
    else
      {:error, :invalid_description}
    end
  end

  defp validate_description(_), do: {:error, :invalid_description}

  defp validate_website(nil), do: :ok

  defp validate_website(website) when is_binary(website) do
    if String.starts_with?(website, "http://") or String.starts_with?(website, "https://") do
      :ok
    else
      {:error, :invalid_website}
    end
  end

  defp validate_website(_), do: {:error, :invalid_website}

  defp validate_credentials(nil), do: :ok

  defp validate_credentials(credentials) when is_binary(credentials) do
    if String.length(credentials) <= 1000 do
      :ok
    else
      {:error, :invalid_credentials}
    end
  end

  defp validate_credentials(_), do: {:error, :invalid_credentials}
end
