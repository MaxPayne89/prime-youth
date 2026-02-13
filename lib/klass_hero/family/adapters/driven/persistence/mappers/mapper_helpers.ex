defmodule KlassHero.Family.Adapters.Driven.Persistence.Mappers.MapperHelpers do
  @moduledoc """
  Shared helper functions for profile mappers.

  Provides common conversion utilities for tier atoms/strings and optional id handling.
  """

  # Known valid tiers - ensures atoms exist for String.to_existing_atom/1
  @parent_tiers [:explorer, :active]
  @provider_tiers [:starter, :professional, :business_plus]
  @all_tiers @parent_tiers ++ @provider_tiers

  @doc """
  Converts a string tier to an atom, returning the default if nil or unknown.

  Uses String.to_existing_atom/1 to prevent atom table exhaustion from
  untrusted input. Falls back to default if the atom doesn't exist or
  isn't in the allowed tier list.
  """
  @spec string_to_tier(String.t() | nil, atom()) :: atom()
  def string_to_tier(nil, default), do: default

  def string_to_tier(tier, default) when is_binary(tier) do
    atom = String.to_existing_atom(tier)

    if atom in @all_tiers do
      atom
    else
      default
    end
  rescue
    ArgumentError -> default
  end

  @doc """
  Converts an atom tier to a string, returning the default string if nil.
  """
  @spec tier_to_string(atom() | nil, String.t()) :: String.t()
  def tier_to_string(nil, default), do: default
  def tier_to_string(tier, _default) when is_atom(tier), do: Atom.to_string(tier)

  @doc """
  Conditionally adds an id to attrs map if the id is not nil.
  """
  @spec maybe_add_id(map(), String.t() | nil) :: map()
  def maybe_add_id(attrs, nil), do: attrs
  def maybe_add_id(attrs, id), do: Map.put(attrs, :id, id)
end
