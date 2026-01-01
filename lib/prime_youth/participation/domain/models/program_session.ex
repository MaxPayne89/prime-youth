defmodule PrimeYouth.Participation.Domain.Models.ProgramSession do
  @moduledoc """
  Pure domain entity representing a scheduled program session.

  ## Design Principles

  This is a pure Elixir struct with no Ecto dependencies, following DDD principles:

  - **Persistence Ignorance**: No knowledge of database schemas or Ecto
  - **Framework Independence**: Pure Elixir struct usable in any context
  - **Encapsulated Business Logic**: All validation and state transitions are domain methods

  ## Status Lifecycle

  ```
  :scheduled → :in_progress → :completed
       ↓
  :cancelled
  ```

  ## Time Handling

  - `session_date`: Local date (Date.t())
  - `start_time` / `end_time`: Local time (Time.t())
  - `inserted_at` / `updated_at`: UTC timestamps (DateTime.t())
  """

  @enforce_keys [:id, :program_id, :session_date, :start_time, :end_time, :status]
  defstruct [
    :id,
    :program_id,
    :session_date,
    :start_time,
    :end_time,
    :status,
    :location,
    :notes,
    :max_capacity,
    :inserted_at,
    :updated_at,
    lock_version: 1
  ]

  @type status :: :scheduled | :in_progress | :completed | :cancelled

  @type t :: %__MODULE__{
          id: String.t(),
          program_id: String.t(),
          session_date: Date.t(),
          start_time: Time.t(),
          end_time: Time.t(),
          status: status(),
          location: String.t() | nil,
          notes: String.t() | nil,
          max_capacity: pos_integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          lock_version: pos_integer()
        }

  @valid_statuses [:scheduled, :in_progress, :completed, :cancelled]

  @doc """
  Creates a new program session in scheduled status.

  ## Examples

      iex> ProgramSession.new(%{
      ...>   id: "sess-123",
      ...>   program_id: "prog-456",
      ...>   session_date: ~D[2024-01-15],
      ...>   start_time: ~T[09:00:00],
      ...>   end_time: ~T[12:00:00]
      ...> })
      {:ok, %ProgramSession{status: :scheduled, ...}}

  """
  @spec new(map()) :: {:ok, t()} | {:error, :missing_required_fields | :invalid_time_range}
  def new(attrs) when is_map(attrs) do
    with {:ok, id} <- Map.fetch(attrs, :id),
         {:ok, program_id} <- Map.fetch(attrs, :program_id),
         {:ok, session_date} <- Map.fetch(attrs, :session_date),
         {:ok, start_time} <- Map.fetch(attrs, :start_time),
         {:ok, end_time} <- Map.fetch(attrs, :end_time),
         :ok <- validate_time_range(start_time, end_time) do
      session = %__MODULE__{
        id: id,
        program_id: program_id,
        session_date: session_date,
        start_time: start_time,
        end_time: end_time,
        status: :scheduled,
        location: Map.get(attrs, :location),
        notes: Map.get(attrs, :notes),
        max_capacity: Map.get(attrs, :max_capacity),
        lock_version: 1
      }

      {:ok, session}
    else
      :error -> {:error, :missing_required_fields}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_time_range(start_time, end_time) do
    case Time.compare(start_time, end_time) do
      :lt -> :ok
      _ -> {:error, :invalid_time_range}
    end
  end

  @doc """
  Starts the session.

  Returns error if not in :scheduled status.
  """
  @spec start(t()) :: {:ok, t()} | {:error, :invalid_status_transition}
  def start(%__MODULE__{status: :scheduled} = session) do
    {:ok, %{session | status: :in_progress}}
  end

  def start(%__MODULE__{}) do
    {:error, :invalid_status_transition}
  end

  @doc """
  Completes the session.

  Returns error if not in :in_progress status.
  """
  @spec complete(t()) :: {:ok, t()} | {:error, :invalid_status_transition}
  def complete(%__MODULE__{status: :in_progress} = session) do
    {:ok, %{session | status: :completed}}
  end

  def complete(%__MODULE__{}) do
    {:error, :invalid_status_transition}
  end

  @doc """
  Cancels the session.

  Can only cancel scheduled sessions.
  """
  @spec cancel(t()) :: {:ok, t()} | {:error, :invalid_status_transition}
  def cancel(%__MODULE__{status: :scheduled} = session) do
    {:ok, %{session | status: :cancelled}}
  end

  def cancel(%__MODULE__{}) do
    {:error, :invalid_status_transition}
  end

  @doc "Returns true if session can accept new participants."
  @spec can_accept_participants?(t()) :: boolean()
  def can_accept_participants?(%__MODULE__{status: status})
      when status in [:scheduled, :in_progress] do
    true
  end

  def can_accept_participants?(%__MODULE__{}), do: false

  @doc "Returns true if session is currently active."
  @spec in_progress?(t()) :: boolean()
  def in_progress?(%__MODULE__{status: :in_progress}), do: true
  def in_progress?(%__MODULE__{}), do: false

  @doc "Returns the duration of the session in minutes."
  @spec duration_minutes(t()) :: non_neg_integer()
  def duration_minutes(%__MODULE__{start_time: start_time, end_time: end_time}) do
    Time.diff(end_time, start_time, :minute)
  end

  @doc "Returns list of valid status atoms."
  @spec valid_statuses() :: [status()]
  def valid_statuses, do: @valid_statuses
end
