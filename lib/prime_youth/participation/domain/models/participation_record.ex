defmodule PrimeYouth.Participation.Domain.Models.ParticipationRecord do
  @moduledoc """
  Pure domain entity representing a child's participation in a program session.

  ## Design Principles

  This is a pure Elixir struct with no Ecto dependencies, following DDD principles:

  - **Persistence Ignorance**: No knowledge of database schemas or Ecto
  - **Framework Independence**: Pure Elixir struct usable in any context
  - **Encapsulated Business Logic**: All validation and state transitions are domain methods

  ## Status Lifecycle

  ```
  :registered → :checked_in → :checked_out
                    ↓
               :absent (if session completed without check-in)
  ```

  ## Timestamps

  All timestamp fields (`check_in_at`, `check_out_at`, `inserted_at`, `updated_at`)
  are `DateTime.t()` in UTC timezone.
  """

  @enforce_keys [:id, :session_id, :child_id, :status]
  defstruct [
    :id,
    :session_id,
    :child_id,
    :parent_id,
    :provider_id,
    :status,
    :check_in_at,
    :check_in_notes,
    :check_in_by,
    :check_out_at,
    :check_out_notes,
    :check_out_by,
    :inserted_at,
    :updated_at,
    lock_version: 1
  ]

  @type status :: :registered | :checked_in | :checked_out | :absent

  @type t :: %__MODULE__{
          id: String.t(),
          session_id: String.t(),
          child_id: String.t(),
          parent_id: String.t() | nil,
          provider_id: String.t() | nil,
          status: status(),
          check_in_at: DateTime.t() | nil,
          check_in_notes: String.t() | nil,
          check_in_by: String.t() | nil,
          check_out_at: DateTime.t() | nil,
          check_out_notes: String.t() | nil,
          check_out_by: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          lock_version: pos_integer()
        }

  @valid_statuses [:registered, :checked_in, :checked_out, :absent]

  @doc """
  Creates a new participation record in registered status.

  ## Examples

      iex> ParticipationRecord.new(%{
      ...>   id: "rec-123",
      ...>   session_id: "sess-456",
      ...>   child_id: "child-789",
      ...>   parent_id: "parent-abc"
      ...> })
      {:ok, %ParticipationRecord{status: :registered, ...}}

  """
  @spec new(map()) :: {:ok, t()} | {:error, :missing_required_fields}
  def new(attrs) when is_map(attrs) do
    with {:ok, id} <- Map.fetch(attrs, :id),
         {:ok, session_id} <- Map.fetch(attrs, :session_id),
         {:ok, child_id} <- Map.fetch(attrs, :child_id) do
      record = %__MODULE__{
        id: id,
        session_id: session_id,
        child_id: child_id,
        parent_id: Map.get(attrs, :parent_id),
        provider_id: Map.get(attrs, :provider_id),
        status: :registered,
        lock_version: 1
      }

      {:ok, record}
    else
      :error -> {:error, :missing_required_fields}
    end
  end

  @doc """
  Checks in the child to the session.

  Returns error if not in :registered status.
  """
  @spec check_in(t(), String.t(), String.t() | nil) ::
          {:ok, t()} | {:error, :invalid_status_transition}
  def check_in(record, checked_in_by, notes \\ nil)

  def check_in(%__MODULE__{status: :registered} = record, checked_in_by, notes) do
    updated =
      %{
        record
        | status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: checked_in_by,
          check_in_notes: notes
      }

    {:ok, updated}
  end

  def check_in(%__MODULE__{}, _checked_in_by, _notes) do
    {:error, :invalid_status_transition}
  end

  @doc """
  Checks out the child from the session.

  Returns error if not in :checked_in status.
  """
  @spec check_out(t(), String.t(), String.t() | nil) ::
          {:ok, t()} | {:error, :invalid_status_transition}
  def check_out(record, checked_out_by, notes \\ nil)

  def check_out(%__MODULE__{status: :checked_in} = record, checked_out_by, notes) do
    updated =
      %{
        record
        | status: :checked_out,
          check_out_at: DateTime.utc_now(),
          check_out_by: checked_out_by,
          check_out_notes: notes
      }

    {:ok, updated}
  end

  def check_out(%__MODULE__{}, _checked_out_by, _notes) do
    {:error, :invalid_status_transition}
  end

  @doc """
  Marks the child as absent (session completed without check-in).

  Returns error if already checked in or checked out.
  """
  @spec mark_absent(t()) :: {:ok, t()} | {:error, :invalid_status_transition}
  def mark_absent(%__MODULE__{status: :registered} = record) do
    {:ok, %{record | status: :absent}}
  end

  def mark_absent(%__MODULE__{}) do
    {:error, :invalid_status_transition}
  end

  @doc "Returns true if child is currently checked in."
  @spec checked_in?(t()) :: boolean()
  def checked_in?(%__MODULE__{status: :checked_in}), do: true
  def checked_in?(%__MODULE__{}), do: false

  @doc "Returns true if child has completed their session (checked out)."
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{status: :checked_out}), do: true
  def completed?(%__MODULE__{}), do: false

  @doc "Returns list of valid status atoms."
  @spec valid_statuses() :: [status()]
  def valid_statuses, do: @valid_statuses
end
