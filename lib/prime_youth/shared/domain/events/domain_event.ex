defmodule PrimeYouth.Shared.Domain.Events.DomainEvent do
  @moduledoc """
  Base structure for all domain events across bounded contexts.

  All domain events include:
  - `event_id`: Unique identifier for this event instance (UUID)
  - `event_type`: Atom identifying the event type (e.g., :user_registered)
  - `aggregate_id`: ID of the entity that generated the event
  - `aggregate_type`: Type of entity (e.g., :user, :program, :enrollment)
  - `occurred_at`: UTC timestamp when the event occurred
  - `payload`: Event-specific data as a map
  - `metadata`: Optional context (correlation_id, causation_id, user_id, criticality)

  ## Event Criticality

  Events can be marked with a criticality level via metadata:
  - `:critical` - Must not be lost (for future guaranteed delivery support)
  - `:normal` - Standard fire-and-forget (default)
  """

  @type criticality :: :critical | :normal

  @type t :: %__MODULE__{
          event_id: String.t(),
          event_type: atom(),
          aggregate_id: String.t() | integer(),
          aggregate_type: atom(),
          occurred_at: DateTime.t(),
          payload: map(),
          metadata: map()
        }

  @enforce_keys [:event_id, :event_type, :aggregate_id, :aggregate_type, :occurred_at, :payload]
  defstruct [
    :event_id,
    :event_type,
    :aggregate_id,
    :aggregate_type,
    :occurred_at,
    :payload,
    metadata: %{}
  ]

  @doc """
  Creates a new domain event with auto-generated ID and timestamp.

  ## Options
  - `:criticality` - Event criticality level (:critical or :normal, default: :normal)
  - `:correlation_id` - ID to correlate related events
  - `:causation_id` - ID of the event that caused this event
  - `:user_id` - ID of the user who triggered the action

  ## Examples

      iex> event = DomainEvent.new(:user_registered, 123, :user, %{email: "test@example.com"})
      iex> event.event_type
      :user_registered
      iex> event.aggregate_id
      123

      iex> event = DomainEvent.new(:order_placed, "uuid", :order, %{total: 100}, criticality: :critical)
      iex> DomainEvent.critical?(event)
      true
  """
  @spec new(atom(), String.t() | integer(), atom(), map(), keyword()) :: t()
  def new(event_type, aggregate_id, aggregate_type, payload, opts \\ []) do
    metadata = build_metadata(opts)

    %__MODULE__{
      event_id: generate_event_id(),
      event_type: event_type,
      aggregate_id: aggregate_id,
      aggregate_type: aggregate_type,
      occurred_at: DateTime.utc_now(),
      payload: payload,
      metadata: metadata
    }
  end

  @doc """
  Returns the criticality level of the event (defaults to :normal).
  """
  @spec criticality(t()) :: criticality()
  def criticality(%__MODULE__{metadata: %{criticality: level}}), do: level
  def criticality(%__MODULE__{}), do: :normal

  @doc """
  Returns true if this is a critical event.
  """
  @spec critical?(t()) :: boolean()
  def critical?(event), do: criticality(event) == :critical

  @doc """
  Returns the correlation_id from metadata if present.
  """
  @spec correlation_id(t()) :: String.t() | nil
  def correlation_id(%__MODULE__{metadata: %{correlation_id: id}}), do: id
  def correlation_id(%__MODULE__{}), do: nil

  @doc """
  Returns the causation_id from metadata if present.
  """
  @spec causation_id(t()) :: String.t() | nil
  def causation_id(%__MODULE__{metadata: %{causation_id: id}}), do: id
  def causation_id(%__MODULE__{}), do: nil

  defp generate_event_id do
    Ecto.UUID.generate()
  end

  defp build_metadata(opts) do
    base = %{
      criticality: Keyword.get(opts, :criticality, :normal)
    }

    base
    |> maybe_add(:correlation_id, opts)
    |> maybe_add(:causation_id, opts)
    |> maybe_add(:user_id, opts)
  end

  defp maybe_add(map, key, opts) do
    case Keyword.get(opts, key) do
      nil -> map
      value -> Map.put(map, key, value)
    end
  end
end
