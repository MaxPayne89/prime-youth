defmodule KlassHero.Enrollment.Domain.Models.Enrollment do
  @moduledoc """
  Pure domain entity representing an enrollment in the Enrollment bounded context.

  This is the aggregate root for enrollment-related operations.
  Contains business logic for enrollment lifecycle management.

  ## Status Lifecycle

      :pending → :confirmed → :completed
          ↓           ↓
      :cancelled  :cancelled

  - `pending` - Enrollment created, awaiting confirmation/payment
  - `confirmed` - Enrollment confirmed and active
  - `completed` - Program/enrollment period finished
  - `cancelled` - Enrollment cancelled (from pending or confirmed)
  """

  @enforce_keys [:id, :program_id, :child_id, :parent_id, :status, :enrolled_at]

  defstruct [
    :id,
    :program_id,
    :child_id,
    :parent_id,
    :status,
    :enrolled_at,
    :confirmed_at,
    :completed_at,
    :cancelled_at,
    :cancellation_reason,
    :subtotal,
    :vat_amount,
    :card_fee_amount,
    :total_amount,
    :payment_method,
    :special_requirements,
    :inserted_at,
    :updated_at
  ]

  @type status :: :pending | :confirmed | :completed | :cancelled

  @type t :: %__MODULE__{
          id: String.t(),
          program_id: String.t(),
          child_id: String.t(),
          parent_id: String.t(),
          status: status(),
          enrolled_at: DateTime.t(),
          confirmed_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          cancelled_at: DateTime.t() | nil,
          cancellation_reason: String.t() | nil,
          subtotal: Decimal.t() | nil,
          vat_amount: Decimal.t() | nil,
          card_fee_amount: Decimal.t() | nil,
          total_amount: Decimal.t() | nil,
          payment_method: String.t() | nil,
          special_requirements: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @valid_statuses [:pending, :confirmed, :completed, :cancelled]
  @valid_payment_methods ["card", "transfer"]

  @doc """
  Creates a new Enrollment with validation.

  Requires:
  - id (UUID string)
  - program_id (UUID string)
  - child_id (UUID string)
  - parent_id (UUID string)
  - status (atom: pending, confirmed, completed, or cancelled)
  - enrolled_at (DateTime)

  Returns:
  - `{:ok, enrollment}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors
  """
  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    attrs = normalize_attrs(attrs)

    case build_struct(attrs) do
      {:ok, enrollment} ->
        case validate(enrollment) do
          [] -> {:ok, enrollment}
          errors -> {:error, errors}
        end

      {:error, reason} ->
        {:error, [reason]}
    end
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Map.put_new(:status, :pending)
    |> Map.put_new(:enrolled_at, DateTime.utc_now())
  end

  defp build_struct(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, "Missing required fields"}
  end

  @doc """
  Confirms a pending enrollment.

  Returns:
  - `{:ok, enrollment}` with status changed to :confirmed and confirmed_at set
  - `{:error, :invalid_status_transition}` if not pending
  """
  @spec confirm(t()) :: {:ok, t()} | {:error, :invalid_status_transition}
  def confirm(%__MODULE__{status: :pending} = enrollment) do
    {:ok, %{enrollment | status: :confirmed, confirmed_at: DateTime.utc_now()}}
  end

  def confirm(%__MODULE__{}), do: {:error, :invalid_status_transition}

  @doc """
  Completes a confirmed enrollment.

  Returns:
  - `{:ok, enrollment}` with status changed to :completed and completed_at set
  - `{:error, :invalid_status_transition}` if not confirmed
  """
  @spec complete(t()) :: {:ok, t()} | {:error, :invalid_status_transition}
  def complete(%__MODULE__{status: :confirmed} = enrollment) do
    {:ok, %{enrollment | status: :completed, completed_at: DateTime.utc_now()}}
  end

  def complete(%__MODULE__{}), do: {:error, :invalid_status_transition}

  @doc """
  Cancels a pending or confirmed enrollment.

  Returns:
  - `{:ok, enrollment}` with status changed to :cancelled
  - `{:error, :invalid_status_transition}` if already completed or cancelled
  """
  @spec cancel(t(), String.t() | nil) :: {:ok, t()} | {:error, :invalid_status_transition}
  def cancel(enrollment, reason \\ nil)

  def cancel(%__MODULE__{status: status} = enrollment, reason)
      when status in [:pending, :confirmed] do
    {:ok,
     %{
       enrollment
       | status: :cancelled,
         cancelled_at: DateTime.utc_now(),
         cancellation_reason: reason
     }}
  end

  def cancel(%__MODULE__{}, _reason), do: {:error, :invalid_status_transition}

  @doc "Returns true if enrollment status is :pending"
  @spec pending?(t()) :: boolean()
  def pending?(%__MODULE__{status: :pending}), do: true
  def pending?(%__MODULE__{}), do: false

  @doc "Returns true if enrollment status is :confirmed"
  @spec confirmed?(t()) :: boolean()
  def confirmed?(%__MODULE__{status: :confirmed}), do: true
  def confirmed?(%__MODULE__{}), do: false

  @doc "Returns true if enrollment status is :completed"
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{status: :completed}), do: true
  def completed?(%__MODULE__{}), do: false

  @doc "Returns true if enrollment status is :cancelled"
  @spec cancelled?(t()) :: boolean()
  def cancelled?(%__MODULE__{status: :cancelled}), do: true
  def cancelled?(%__MODULE__{}), do: false

  @doc "Returns true if enrollment is active (pending or confirmed)"
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: status}) when status in [:pending, :confirmed], do: true
  def active?(%__MODULE__{}), do: false

  @doc "Returns all valid enrollment statuses"
  @spec valid_statuses() :: [status()]
  def valid_statuses, do: @valid_statuses

  @doc "Returns all valid payment methods"
  @spec valid_payment_methods() :: [String.t()]
  def valid_payment_methods, do: @valid_payment_methods

  defp validate(%__MODULE__{} = enrollment) do
    []
    |> validate_uuid(:id, enrollment.id)
    |> validate_uuid(:program_id, enrollment.program_id)
    |> validate_uuid(:child_id, enrollment.child_id)
    |> validate_uuid(:parent_id, enrollment.parent_id)
    |> validate_status(enrollment.status)
    |> validate_enrolled_at(enrollment.enrolled_at)
    |> validate_payment_method(enrollment.payment_method)
  end

  defp validate_uuid(errors, field, value) when is_binary(value) do
    if String.trim(value) == "" do
      ["#{field} cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_uuid(errors, field, _), do: ["#{field} must be a string" | errors]

  defp validate_status(errors, status) when status in @valid_statuses, do: errors

  defp validate_status(errors, _) do
    valid = @valid_statuses |> Enum.map_join(", ", &to_string/1)
    ["Status must be one of: #{valid}" | errors]
  end

  defp validate_enrolled_at(errors, %DateTime{}), do: errors
  defp validate_enrolled_at(errors, _), do: ["enrolled_at must be a DateTime" | errors]

  defp validate_payment_method(errors, nil), do: errors
  defp validate_payment_method(errors, method) when method in @valid_payment_methods, do: errors

  defp validate_payment_method(errors, _) do
    valid = @valid_payment_methods |> Enum.join(", ")
    ["Payment method must be one of: #{valid}" | errors]
  end
end
