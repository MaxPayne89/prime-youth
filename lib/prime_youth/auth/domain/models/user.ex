defmodule PrimeYouth.Auth.Domain.Models.User do
  @moduledoc """
  Domain entity representing a user in the authentication context.

  Follows the Funx functional programming pattern with:
  - Elixir 1.19 typed structs for type safety
  - Either-based validation with error accumulation
  - Never-fail constructors with self-healing
  - Protocol implementations for Eq and Ord
  """

  import Funx.Predicate

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either

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

  # Domain constants
  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  @max_email_length 160
  @max_name_length 100

  # ============================================================================
  # Predicate Functions (boolean checks)
  # ============================================================================

  @doc """
  Checks if email is invalid (does not match email format or exceeds length).
  """
  def invalid_email?(%__MODULE__{email: email}) when is_binary(email) do
    email = String.trim(email)
    String.length(email) > @max_email_length or not Regex.match?(@email_regex, email)
  end

  def invalid_email?(%__MODULE__{email: email}) when is_nil(email), do: true
  def invalid_email?(%__MODULE__{}), do: true

  @doc """
  Checks if first name is invalid (nil, empty, or exceeds length).
  First name is required for user registration.
  """
  def invalid_first_name?(%__MODULE__{first_name: nil}), do: true
  def invalid_first_name?(%__MODULE__{first_name: ""}), do: true

  def invalid_first_name?(%__MODULE__{first_name: name}) when is_binary(name) do
    trimmed = String.trim(name)
    String.length(trimmed) == 0 or String.length(trimmed) > @max_name_length
  end

  def invalid_first_name?(%__MODULE__{}), do: true

  @doc """
  Checks if last name is invalid (nil, empty, or exceeds length).
  Last name is required for user registration.
  """
  def invalid_last_name?(%__MODULE__{last_name: nil}), do: true
  def invalid_last_name?(%__MODULE__{last_name: ""}), do: true

  def invalid_last_name?(%__MODULE__{last_name: name}) when is_binary(name) do
    trimmed = String.trim(name)
    String.length(trimmed) == 0 or String.length(trimmed) > @max_name_length
  end

  def invalid_last_name?(%__MODULE__{}), do: true

  @doc """
  Checks if confirmed_at timestamp is invalid.
  Must be a valid DateTime struct or nil (not yet confirmed).
  """
  def invalid_confirmed_at?(%__MODULE__{confirmed_at: nil}), do: false
  def invalid_confirmed_at?(%__MODULE__{confirmed_at: %DateTime{}}), do: false
  def invalid_confirmed_at?(%__MODULE__{}), do: true

  @doc """
  Checks if authenticated_at timestamp is invalid.
  Must be a valid DateTime struct or nil (not yet authenticated).
  """
  def invalid_authenticated_at?(%__MODULE__{authenticated_at: nil}), do: false
  def invalid_authenticated_at?(%__MODULE__{authenticated_at: %DateTime{}}), do: false
  def invalid_authenticated_at?(%__MODULE__{}), do: true

  @doc """
  Checks if hashed_password is invalid.
  Must be a non-empty string when present. Nil is allowed for users
  without password-based authentication (e.g., OAuth users).
  """
  def invalid_hashed_password?(%__MODULE__{hashed_password: nil}), do: false

  def invalid_hashed_password?(%__MODULE__{hashed_password: hash}) when is_binary(hash) do
    String.trim(hash) == ""
  end

  def invalid_hashed_password?(%__MODULE__{}), do: true

  # ============================================================================
  # Validation Functions (Either-wrapped)
  # ============================================================================

  @doc """
  Ensures the user has a valid email address.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def ensure_valid_email(%__MODULE__{} = user) do
    user
    |> Either.lift_predicate(
      p_not(&invalid_email?/1),
      fn u ->
        cond do
          is_nil(u.email) or u.email == "" ->
            "Email is required"

          String.length(String.trim(u.email)) > @max_email_length ->
            "Email '#{u.email}' is too long (max #{@max_email_length} chars)"

          true ->
            "Email '#{u.email}' has invalid format"
        end
      end
    )
    |> Either.map_left(&ValidationError.new/1)
  end

  @doc """
  Ensures the user's first name is valid and present.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def ensure_valid_first_name(%__MODULE__{} = user) do
    user
    |> Either.lift_predicate(
      p_not(&invalid_first_name?/1),
      fn u ->
        cond do
          is_nil(u.first_name) or u.first_name == "" ->
            "First name is required"

          String.length(String.trim(u.first_name)) > @max_name_length ->
            "First name '#{u.first_name}' is too long (max #{@max_name_length} chars)"

          true ->
            "First name is invalid"
        end
      end
    )
    |> Either.map_left(&ValidationError.new/1)
  end

  @doc """
  Ensures the user's last name is valid and present.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def ensure_valid_last_name(%__MODULE__{} = user) do
    user
    |> Either.lift_predicate(
      p_not(&invalid_last_name?/1),
      fn u ->
        cond do
          is_nil(u.last_name) or u.last_name == "" ->
            "Last name is required"

          String.length(String.trim(u.last_name)) > @max_name_length ->
            "Last name '#{u.last_name}' is too long (max #{@max_name_length} chars)"

          true ->
            "Last name is invalid"
        end
      end
    )
    |> Either.map_left(&ValidationError.new/1)
  end

  @doc """
  Ensures the user's confirmation timestamp is valid.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def ensure_valid_confirmed_at(%__MODULE__{} = user) do
    user
    |> Either.lift_predicate(
      p_not(&invalid_confirmed_at?/1),
      fn u ->
        "Confirmation timestamp '#{inspect(u.confirmed_at)}' must be a valid DateTime or nil"
      end
    )
    |> Either.map_left(&ValidationError.new/1)
  end

  @doc """
  Ensures the user's authentication timestamp is valid.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def ensure_valid_authenticated_at(%__MODULE__{} = user) do
    user
    |> Either.lift_predicate(
      p_not(&invalid_authenticated_at?/1),
      fn u ->
        "Authentication timestamp '#{inspect(u.authenticated_at)}' must be a valid DateTime or nil"
      end
    )
    |> Either.map_left(&ValidationError.new/1)
  end

  @doc """
  Ensures the user's hashed password is valid.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def ensure_valid_hashed_password(%__MODULE__{} = user) do
    user
    |> Either.lift_predicate(
      p_not(&invalid_hashed_password?/1),
      fn u ->
        "Hashed password '#{inspect(u.hashed_password)}' must be a non-empty string or nil"
      end
    )
    |> Either.map_left(&ValidationError.new/1)
  end

  @doc """
  Comprehensive validation that collects ALL errors.
  Returns Either.Right(user) if all validations pass,
  or Either.Left(ValidationError) with all accumulated errors.
  """
  def validate(%__MODULE__{} = user) do
    user
    |> Either.validate([
      &ensure_valid_email/1,
      &ensure_valid_first_name/1,
      &ensure_valid_last_name/1,
      &ensure_valid_confirmed_at/1,
      &ensure_valid_authenticated_at/1,
      &ensure_valid_hashed_password/1
    ])
  end

  # ============================================================================
  # Constructor (Returns Either)
  # ============================================================================

  @doc """
  Creates a new user with validation. Returns Either.Left(errors) or Either.Right(user).

  Email and names are normalized (trimmed, email lowercased) before validation.

  ## Examples

      iex> make("test@example.com", first_name: "John", last_name: "Doe")
      %Either.Right{right: %User{email: "test@example.com", first_name: "John", last_name: "Doe"}}

      iex> make("  ", first_name: "John")  # Invalid email returns errors
      %Either.Left{left: %ValidationError{errors: ["Email is required"]}}
  """
  def make(email, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id),
      email: normalize_email(email),
      first_name: normalize_name(Keyword.get(opts, :first_name)),
      last_name: normalize_name(Keyword.get(opts, :last_name)),
      hashed_password: Keyword.get(opts, :hashed_password),
      confirmed_at: Keyword.get(opts, :confirmed_at),
      authenticated_at: Keyword.get(opts, :authenticated_at),
      inserted_at: Keyword.get(opts, :inserted_at),
      updated_at: Keyword.get(opts, :updated_at)
    }
    |> validate()
  end

  # ============================================================================
  # Change Function (Returns Either)
  # ============================================================================

  @doc """
  Updates user attributes with validation. Returns Either.Left(errors) or Either.Right(user).
  Protects ID from modification. Normalizes email and names before validation.
  """
  def change(%__MODULE__{} = user, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.delete(:id)
      |> normalize_attrs()

    struct(user, attrs) |> validate()
  end

  defp normalize_attrs(attrs) do
    attrs
    |> then(fn a ->
      if Map.has_key?(a, :email), do: Map.update!(a, :email, &normalize_email/1), else: a
    end)
    |> then(fn a ->
      if Map.has_key?(a, :first_name), do: Map.update!(a, :first_name, &normalize_name/1), else: a
    end)
    |> then(fn a ->
      if Map.has_key?(a, :last_name), do: Map.update!(a, :last_name, &normalize_name/1), else: a
    end)
    |> then(fn a ->
      if Map.has_key?(a, :confirmed_at),
        do: Map.update!(a, :confirmed_at, &normalize_timestamp/1),
        else: a
    end)
    |> then(fn a ->
      if Map.has_key?(a, :authenticated_at),
        do: Map.update!(a, :authenticated_at, &normalize_timestamp/1),
        else: a
    end)
  end

  # ============================================================================
  # Normalization Functions
  # ============================================================================

  # Normalizes email to canonical form: trimmed and lowercased.
  # Does not validate - use validate/1 for validation.
  defp normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  defp normalize_email(_), do: ""

  # Normalizes name to canonical form: trimmed.
  # Does not validate - use validate/1 for validation.
  defp normalize_name(name) when is_binary(name) do
    String.trim(name)
  end

  defp normalize_name(_), do: nil

  # Normalizes timestamp to canonical form: DateTime or nil.
  # Does not validate - use validate/1 for validation.
  # Invalid timestamps are NOT healed to nil - they will fail validation.
  defp normalize_timestamp(%DateTime{} = dt), do: dt
  defp normalize_timestamp(nil), do: nil
  defp normalize_timestamp(value), do: value

  # ============================================================================
  # Domain Operations
  # ============================================================================

  @doc """
  Confirms the user account by setting the confirmed_at timestamp.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def confirm(%__MODULE__{} = user, confirmed_at) do
    change(user, %{confirmed_at: confirmed_at})
  end

  @doc """
  Marks the user as authenticated by setting the authenticated_at timestamp.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def authenticate(%__MODULE__{} = user, authenticated_at) do
    change(user, %{authenticated_at: authenticated_at})
  end

  @doc """
  Updates the user's email address with validation.
  Email is normalized (trimmed and lowercased) before validation.
  Resets confirmation status when email changes.
  Returns Either.Right(user) or Either.Left(ValidationError).
  """
  def update_email(%__MODULE__{} = user, new_email) do
    change(user, %{email: new_email, confirmed_at: nil})
  end

  @doc """
  Validates whether the user is confirmed.
  """
  def confirmed?(%__MODULE__{confirmed_at: nil}), do: false
  def confirmed?(%__MODULE__{confirmed_at: _}), do: true

  # ============================================================================
  # Field Accessors (Encapsulation)
  # ============================================================================

  @doc "Returns the user's ID"
  def id(%__MODULE__{id: id}), do: id

  @doc "Returns the user's email"
  def email(%__MODULE__{email: email}), do: email

  @doc "Returns the user's first name"
  def first_name(%__MODULE__{first_name: name}), do: name

  @doc "Returns the user's last name"
  def last_name(%__MODULE__{last_name: name}), do: name

  @doc "Returns the user's full name"
  def full_name(%__MODULE__{first_name: first, last_name: last}) do
    [first, last] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end
end

# ============================================================================
# Protocol Implementations
# ============================================================================

defimpl Funx.Eq, for: PrimeYouth.Auth.Domain.Models.User do
  @moduledoc """
  Equality protocol implementation for User.
  Users are equal if they have the same ID (identity-based equality).
  """

  alias Funx.Eq
  alias PrimeYouth.Auth.Domain.Models.User

  def eq?(%User{id: id1}, %User{id: id2}), do: Eq.eq?(id1, id2)
  def not_eq?(%User{id: id1}, %User{id: id2}), do: not eq?(id1, id2)
end

defimpl Funx.Ord, for: PrimeYouth.Auth.Domain.Models.User do
  @moduledoc """
  Ordering protocol implementation for User.
  Users are ordered by last name, then first name, then email.
  """

  alias Funx.Ord
  alias PrimeYouth.Auth.Domain.Models.User

  def lt?(%User{last_name: ln1, first_name: fn1, email: e1}, %User{
        last_name: ln2,
        first_name: fn2,
        email: e2
      }) do
    cond do
      Ord.lt?(ln1, ln2) -> true
      Ord.gt?(ln1, ln2) -> false
      Ord.lt?(fn1, fn2) -> true
      Ord.gt?(fn1, fn2) -> false
      true -> Ord.lt?(e1, e2)
    end
  end

  def le?(%User{last_name: ln1, first_name: fn1, email: e1}, %User{
        last_name: ln2,
        first_name: fn2,
        email: e2
      }) do
    cond do
      Ord.lt?(ln1, ln2) -> true
      Ord.gt?(ln1, ln2) -> false
      Ord.lt?(fn1, fn2) -> true
      Ord.gt?(fn1, fn2) -> false
      true -> Ord.le?(e1, e2)
    end
  end

  def gt?(%User{last_name: ln1, first_name: fn1, email: e1}, %User{
        last_name: ln2,
        first_name: fn2,
        email: e2
      }) do
    cond do
      Ord.gt?(ln1, ln2) -> true
      Ord.lt?(ln1, ln2) -> false
      Ord.gt?(fn1, fn2) -> true
      Ord.lt?(fn1, fn2) -> false
      true -> Ord.gt?(e1, e2)
    end
  end

  def ge?(%User{last_name: ln1, first_name: fn1, email: e1}, %User{
        last_name: ln2,
        first_name: fn2,
        email: e2
      }) do
    cond do
      Ord.gt?(ln1, ln2) -> true
      Ord.lt?(ln1, ln2) -> false
      Ord.gt?(fn1, fn2) -> true
      Ord.lt?(fn1, fn2) -> false
      true -> Ord.ge?(e1, e2)
    end
  end
end
