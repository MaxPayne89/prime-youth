defmodule PrimeYouth.ProgramCatalog.Domain.Entities.Location do
  @moduledoc """
  Location domain entity representing where a program takes place.

  This is a pure Elixir struct that encapsulates location business logic without
  infrastructure concerns. Supports both physical venues and virtual locations.

  ## Business Rules

  - For physical locations (`is_virtual=false`), address fields are required
  - For virtual locations (`is_virtual=true`), `virtual_link` is required
  - Programs can have multiple locations (e.g., rotating venues)
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          program_id: String.t(),
          name: String.t(),
          address_line1: String.t() | nil,
          address_line2: String.t() | nil,
          city: String.t() | nil,
          state: String.t() | nil,
          postal_code: String.t() | nil,
          country: String.t() | nil,
          is_virtual: boolean(),
          virtual_link: String.t() | nil,
          accessibility_notes: String.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:program_id, :name, :is_virtual]

  defstruct [
    :id,
    :program_id,
    :name,
    :address_line1,
    :address_line2,
    :city,
    :state,
    :postal_code,
    :country,
    :virtual_link,
    :accessibility_notes,
    :created_at,
    :updated_at,
    is_virtual: false
  ]

  @doc """
  Creates a new Location entity with validation.

  ## Parameters

  - `attrs`: Map of location attributes

  ## Returns

  - `{:ok, %Location{}}` if valid
  - `{:error, reason}` if validation fails

  ## Examples

      # Physical location
      iex> PrimeYouth.ProgramCatalog.Domain.Entities.Location.new(%{
      ...>   program_id: "program-uuid",
      ...>   name: "Community Center",
      ...>   address_line1: "123 Main St",
      ...>   city: "Springfield",
      ...>   state: "IL",
      ...>   is_virtual: false
      ...> })
      {:ok, %Location{}}

      # Virtual location
      iex> PrimeYouth.ProgramCatalog.Domain.Entities.Location.new(%{
      ...>   program_id: "program-uuid",
      ...>   name: "Online Class",
      ...>   is_virtual: true,
      ...>   virtual_link: "https://zoom.us/j/123456"
      ...> })
      {:ok, %Location{}}

  """
  def new(attrs) when is_map(attrs) do
    with {:ok, attrs} <- validate_required_fields(attrs),
         {:ok, attrs} <- validate_name(attrs),
         {:ok, attrs} <- validate_location_type(attrs) do
      location = struct(__MODULE__, attrs)
      {:ok, location}
    end
  end

  @doc """
  Checks if the location is physical (not virtual).
  """
  def physical?(%__MODULE__{is_virtual: is_virtual}) do
    not is_virtual
  end

  @doc """
  Checks if the location is virtual (online).
  """
  def virtual?(%__MODULE__{is_virtual: is_virtual}) do
    is_virtual
  end

  @doc """
  Formats the location address for display.

  Returns a formatted address string for physical locations or virtual link for virtual locations.
  """
  def format_address(%__MODULE__{is_virtual: true, virtual_link: link}) when is_binary(link) do
    "Virtual: #{link}"
  end

  def format_address(%__MODULE__{is_virtual: true}) do
    "Virtual Location"
  end

  def format_address(%__MODULE__{} = location) do
    parts = [
      location.address_line1,
      location.address_line2,
      location.city,
      location.state,
      location.postal_code,
      location.country
    ]

    parts
    |> Enum.reject(fn part -> is_nil(part) or String.trim(part) == "" end)
    |> Enum.join(", ")
  end

  # Private validation functions

  defp validate_required_fields(attrs) do
    required = [:program_id, :name]

    missing =
      Enum.filter(required, fn field ->
        not Map.has_key?(attrs, field) or is_nil(Map.get(attrs, field))
      end)

    if Enum.empty?(missing) do
      # Set default for is_virtual if not provided
      attrs = Map.put_new(attrs, :is_virtual, false)
      {:ok, attrs}
    else
      {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_name(%{name: name} = attrs) when is_binary(name) do
    name_length = String.length(name)

    cond do
      name_length < 2 -> {:error, :name_too_short}
      name_length > 200 -> {:error, :name_too_long}
      true -> {:ok, attrs}
    end
  end

  defp validate_name(_), do: {:error, :invalid_name}

  defp validate_location_type(%{is_virtual: false} = attrs) do
    # Physical location - require address fields
    required_address_fields = [:address_line1, :city, :state]

    missing =
      Enum.filter(required_address_fields, fn field ->
        value = Map.get(attrs, field)
        is_nil(value) or (is_binary(value) and String.trim(value) == "")
      end)

    if Enum.empty?(missing) do
      validate_address_field_lengths(attrs)
    else
      {:error, {:missing_address_fields, missing}}
    end
  end

  defp validate_location_type(%{is_virtual: true, virtual_link: link} = attrs)
       when is_binary(link) and byte_size(link) > 0 do
    # Virtual location with valid link
    validate_virtual_link(attrs)
  end

  defp validate_location_type(%{is_virtual: true}) do
    {:error, :missing_virtual_link}
  end

  defp validate_location_type(_), do: {:error, :invalid_location_type}

  defp validate_address_field_lengths(attrs) do
    validations = [
      {:address_line1, 200},
      {:address_line2, 200},
      {:city, 100},
      {:state, 100},
      {:postal_code, 20},
      {:country, 100}
    ]

    Enum.reduce_while(validations, {:ok, attrs}, fn {field, max_length}, acc ->
      validate_field_length(attrs, field, max_length, acc)
    end)
  end

  defp validate_field_length(attrs, field, max_length, acc) do
    case Map.get(attrs, field) do
      nil -> {:cont, acc}
      value when is_binary(value) -> check_string_length(value, field, max_length, acc)
      _ -> {:cont, acc}
    end
  end

  defp check_string_length(value, field, max_length, acc) do
    if String.length(value) <= max_length do
      {:cont, acc}
    else
      {:halt, {:error, {:field_too_long, field, max_length}}}
    end
  end

  defp validate_virtual_link(%{virtual_link: link} = attrs) when is_binary(link) do
    # Basic URL validation - check if it looks like a URL
    if String.match?(link, ~r/^https?:\/\//) do
      {:ok, attrs}
    else
      {:error, :invalid_virtual_link_format}
    end
  end

  defp validate_virtual_link(attrs), do: {:ok, attrs}
end
