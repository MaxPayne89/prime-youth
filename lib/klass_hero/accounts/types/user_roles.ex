defmodule KlassHero.Accounts.Types.UserRoles do
  @moduledoc """
  Custom Ecto type for user role arrays.

  Stores roles as PostgreSQL `text[]` (array of strings) in the database,
  but loads them as a list of atoms in Elixir for better pattern matching
  and type safety.

  ## Database Representation
  `["parent", "provider"]`

  ## Elixir Representation
  `[:parent, :provider]`

  ## Event Serialization
  Uses `embed_as(:dump)` to ensure domain events receive string values
  for JSON serialization, maintaining compatibility with event handlers.

  ## Features
  - Automatic deduplication (no duplicate roles)
  - Nil → empty list conversion
  - Accepts both strings (from forms) and atoms (from code)
  - Validates all roles against UserRole.valid_roles()

  ## Examples

      iex> UserRoles.cast([:parent, :provider])
      {:ok, [:parent, :provider]}

      iex> UserRoles.cast(["parent", "provider"])
      {:ok, [:parent, :provider]}

      iex> UserRoles.cast([:parent, :parent])
      {:ok, [:parent]}  # Deduplicated

      iex> UserRoles.cast([:invalid])
      :error
  """

  use Ecto.Type

  alias KlassHero.Accounts.Types.UserRole

  @impl true
  def type, do: {:array, :string}

  @impl true
  def cast(nil), do: {:ok, []}
  def cast([]), do: {:ok, []}

  def cast(roles) when is_list(roles) do
    transform_roles(roles, &normalize_role/1, finalize: &Enum.uniq/1)
  end

  def cast(_), do: :error

  @impl true
  def load(nil), do: {:ok, []}
  def load([]), do: {:ok, []}

  def load(roles) when is_list(roles) do
    transform_roles(roles, fn role_str ->
      case UserRole.from_string(role_str) do
        {:ok, atom_role} -> {:ok, atom_role}
        {:error, _} -> :error
      end
    end)
  end

  def load(_), do: :error

  @impl true
  def dump(nil), do: {:ok, []}
  def dump([]), do: {:ok, []}

  def dump(roles) when is_list(roles) do
    transform_roles(roles, fn role ->
      case UserRole.to_string(role) do
        {:ok, str_role} -> {:ok, str_role}
        {:error, _} -> :error
      end
    end)
  end

  def dump(_), do: :error

  @impl true
  def embed_as(_), do: :dump

  # Private helpers

  defp transform_roles(roles, transform_fn, opts \\ []) do
    finalize = Keyword.get(opts, :finalize, &Function.identity/1)

    roles
    |> Enum.reduce_while([], fn role, acc ->
      case transform_fn.(role) do
        {:ok, transformed} -> {:cont, [transformed | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      transformed -> {:ok, transformed |> Enum.reverse() |> finalize.()}
    end
  end

  defp normalize_role(role) when is_atom(role) do
    if UserRole.valid_role?(role), do: {:ok, role}, else: :error
  end

  defp normalize_role(role) when is_binary(role) do
    case UserRole.from_string(role) do
      {:ok, atom_role} -> {:ok, atom_role}
      {:error, _} -> :error
    end
  end

  defp normalize_role(_), do: :error
end
