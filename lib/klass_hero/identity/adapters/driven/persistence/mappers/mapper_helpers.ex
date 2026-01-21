defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.MapperHelpers do
  @moduledoc """
  Shared helper functions for profile mappers.

  Provides common conversion utilities for tier atoms/strings and optional id handling.
  """

  @doc """
  Converts a string tier to an atom, returning the default if nil.
  """
  @spec string_to_tier(String.t() | nil, atom()) :: atom()
  def string_to_tier(nil, default), do: default
  def string_to_tier(tier, _default) when is_binary(tier), do: String.to_existing_atom(tier)

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
