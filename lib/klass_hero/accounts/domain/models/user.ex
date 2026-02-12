defmodule KlassHero.Accounts.Domain.Models.User do
  @moduledoc """
  User domain entity in the Accounts bounded context.

  Pure domain model with no persistence or infrastructure concerns.
  Excludes auth infrastructure fields (password, hashed_password,
  authenticated_at) which live on the Ecto schema only.

  ## Fields

  - `id` - Unique identifier
  - `email` - User's email address
  - `name` - Display name
  - `avatar` - Optional avatar URL
  - `confirmed_at` - When email was confirmed
  - `is_admin` - Admin flag
  - `locale` - Preferred locale (en, de)
  - `intended_roles` - Roles selected at registration
  - `inserted_at` - Record creation timestamp
  - `updated_at` - Record update timestamp
  """

  @enforce_keys [:id, :email, :name]
  defstruct [
    :id,
    :email,
    :name,
    :avatar,
    :confirmed_at,
    :locale,
    :inserted_at,
    :updated_at,
    is_admin: false,
    intended_roles: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          name: String.t(),
          avatar: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          is_admin: boolean(),
          locale: String.t() | nil,
          intended_roles: [atom()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new User with business validation.

  Returns:
  - `{:ok, user}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors
  """
  def new(attrs) when is_map(attrs) do
    # Validate attrs before struct construction so we get
    # field-level errors instead of a generic ArgumentError
    errors =
      []
      |> validate_email(attrs[:email])
      |> validate_name(attrs[:name])

    case errors do
      [] ->
        {:ok, struct!(__MODULE__, attrs)}

      errors ->
        {:error, errors}
    end
  rescue
    ArgumentError -> {:error, ["Missing required fields"]}
  end

  @doc """
  Reconstructs a User from persistence data.

  Skips business validation since data was validated on write.
  """
  def from_persistence(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, :invalid_persistence_data}
  end

  @doc """
  Returns canonical GDPR anonymization values.

  The domain model owns the definition of what "anonymized" means,
  keeping this business decision out of persistence adapters.
  """
  def anonymized_attrs do
    %{
      name: "Deleted User",
      avatar: nil,
      email_fn: fn user_id -> "deleted_#{user_id}@anonymized.local" end
    }
  end

  @doc """
  Validates that a user struct has valid business rules.
  """
  def valid?(%__MODULE__{} = user) do
    validate(user) == []
  end

  defp validate(%__MODULE__{} = user) do
    []
    |> validate_email(user.email)
    |> validate_name(user.name)
  end

  defp validate_email(errors, email) when is_binary(email) do
    if String.trim(email) == "" do
      ["Email cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_email(errors, _), do: ["Email must be a string" | errors]

  defp validate_name(errors, name) when is_binary(name) do
    if String.trim(name) == "" do
      ["Name cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_name(errors, _), do: ["Name must be a string" | errors]
end
