defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.ApprovalStatus do
  @moduledoc """
  ApprovalStatus value object for program approval workflow.

  Represents the approval state of a program with validation and transition rules:
  - draft: Initial state, editable by provider
  - pending_approval: Submitted for review, not editable
  - approved: Approved by admin, publicly visible
  - rejected: Rejected by admin, needs revision
  - archived: No longer active, read-only

  State Transition Rules:
  - draft → pending_approval, archived
  - pending_approval → approved, rejected, draft
  - approved → archived
  - rejected → draft, archived
  - archived → (no transitions allowed, terminal state)

  Immutable value object following DDD principles.
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  @valid_statuses [
    "draft",
    "pending_approval",
    "approved",
    "rejected",
    "archived"
  ]

  @display_names %{
    "draft" => "Draft",
    "pending_approval" => "Pending Approval",
    "approved" => "Approved",
    "rejected" => "Rejected",
    "archived" => "Archived"
  }

  @transition_rules %{
    "draft" => ["pending_approval", "archived"],
    "pending_approval" => ["approved", "rejected", "draft"],
    "approved" => ["archived"],
    "rejected" => ["draft", "archived"],
    "archived" => []
  }

  @doc """
  Creates a new ApprovalStatus value object.

  ## Parameters
    - value: The status name (string)

  ## Returns
    - `{:ok, %ApprovalStatus{}}` if valid
    - `{:error, reason}` if invalid

  ## Examples

      iex> ApprovalStatus.new("draft")
      {:ok, %ApprovalStatus{value: "draft"}}

      iex> ApprovalStatus.new("APPROVED")
      {:ok, %ApprovalStatus{value: "approved"}}

      iex> ApprovalStatus.new("  pending_approval  ")
      {:ok, %ApprovalStatus{value: "pending_approval"}}

      iex> ApprovalStatus.new("invalid")
      {:error, "Invalid status: invalid"}

      iex> ApprovalStatus.new(nil)
      {:error, "Status cannot be nil"}

      iex> ApprovalStatus.new("")
      {:error, "Status cannot be empty"}
  """
  @spec new(String.t() | nil) :: {:ok, t()} | {:error, String.t()}
  def new(nil), do: {:error, "Status cannot be nil"}

  def new(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    cond do
      normalized == "" ->
        {:error, "Status cannot be empty"}

      normalized not in @valid_statuses ->
        {:error, "Invalid status: #{value}"}

      true ->
        {:ok, %__MODULE__{value: normalized}}
    end
  end

  @doc """
  Creates a draft status.

  Convenience constructor for creating a draft status without error handling.
  Equivalent to calling `new("draft")` and unwrapping the result.

  ## Returns
    - `%ApprovalStatus{value: "draft"}`

  ## Examples

      iex> ApprovalStatus.draft()
      %ApprovalStatus{value: "draft"}

      iex> ApprovalStatus.draft?/1(ApprovalStatus.draft())
      true
  """
  @spec draft() :: t()
  def draft do
    {:ok, status} = new("draft")
    status
  end

  @doc """
  Creates an approved status.

  Convenience constructor for creating an approved status without error handling.
  Equivalent to calling `new("approved")` and unwrapping the result.

  ## Returns
    - `%ApprovalStatus{value: "approved"}`

  ## Examples

      iex> ApprovalStatus.approved()
      %ApprovalStatus{value: "approved"}

      iex> ApprovalStatus.approved?/1(ApprovalStatus.approved())
      true
  """
  @spec approved() :: t()
  def approved do
    {:ok, status} = new("approved")
    status
  end

  @doc """
  Creates a pending_approval status.

  Convenience constructor for creating a pending_approval status without error handling.
  Equivalent to calling `new("pending_approval")` and unwrapping the result.

  ## Returns
    - `%ApprovalStatus{value: "pending_approval"}`

  ## Examples

      iex> ApprovalStatus.pending_approval()
      %ApprovalStatus{value: "pending_approval"}

      iex> ApprovalStatus.pending?/1(ApprovalStatus.pending_approval())
      true
  """
  @spec pending_approval() :: t()
  def pending_approval do
    {:ok, status} = new("pending_approval")
    status
  end

  @doc """
  Creates a rejected status.

  Convenience constructor for creating a rejected status without error handling.
  Equivalent to calling `new("rejected")` and unwrapping the result.

  ## Returns
    - `%ApprovalStatus{value: "rejected"}`

  ## Examples

      iex> ApprovalStatus.rejected()
      %ApprovalStatus{value: "rejected"}

      iex> ApprovalStatus.rejected?/1(ApprovalStatus.rejected())
      true
  """
  @spec rejected() :: t()
  def rejected do
    {:ok, status} = new("rejected")
    status
  end

  @doc """
  Creates an archived status.

  Convenience constructor for creating an archived status without error handling.
  Equivalent to calling `new("archived")` and unwrapping the result.

  ## Returns
    - `%ApprovalStatus{value: "archived"}`

  ## Examples

      iex> ApprovalStatus.archived()
      %ApprovalStatus{value: "archived"}

      iex> ApprovalStatus.archived?/1(ApprovalStatus.archived())
      true
  """
  @spec archived() :: t()
  def archived do
    {:ok, status} = new("archived")
    status
  end

  @doc """
  Returns the formatted display name for a status.

  ## Parameters
    - status: The ApprovalStatus struct

  ## Returns
    - String: The formatted display name

  ## Examples

      iex> {:ok, status} = ApprovalStatus.new("draft")
      iex> ApprovalStatus.display_name(status)
      "Draft"

      iex> {:ok, status} = ApprovalStatus.new("pending_approval")
      iex> ApprovalStatus.display_name(status)
      "Pending Approval"
  """
  @spec display_name(t()) :: String.t()
  def display_name(%__MODULE__{value: value}) do
    Map.get(@display_names, value, String.capitalize(value))
  end

  @doc """
  Returns a list of all valid status values.

  ## Returns
    - List of valid status strings

  ## Examples

      iex> ApprovalStatus.all()
      ["draft", "pending_approval", "approved", "rejected", "archived"]
  """
  @spec all() :: [String.t()]
  def all do
    @valid_statuses
  end

  @doc """
  Checks if the status is draft.

  ## Parameters
    - status: The ApprovalStatus struct

  ## Returns
    - boolean: true if status is draft, false otherwise

  ## Examples

      iex> {:ok, status} = ApprovalStatus.new("draft")
      iex> ApprovalStatus.draft?(status)
      true

      iex> {:ok, status} = ApprovalStatus.new("approved")
      iex> ApprovalStatus.draft?(status)
      false
  """
  @spec draft?(t()) :: boolean()
  def draft?(%__MODULE__{value: "draft"}), do: true
  def draft?(%__MODULE__{}), do: false

  @doc """
  Checks if the status is pending approval.

  ## Parameters
    - status: The ApprovalStatus struct

  ## Returns
    - boolean: true if status is pending_approval, false otherwise

  ## Examples

      iex> {:ok, status} = ApprovalStatus.new("pending_approval")
      iex> ApprovalStatus.pending?(status)
      true

      iex> {:ok, status} = ApprovalStatus.new("approved")
      iex> ApprovalStatus.pending?(status)
      false
  """
  @spec pending?(t()) :: boolean()
  def pending?(%__MODULE__{value: "pending_approval"}), do: true
  def pending?(%__MODULE__{}), do: false

  @doc """
  Checks if the status is approved.

  ## Parameters
    - status: The ApprovalStatus struct

  ## Returns
    - boolean: true if status is approved, false otherwise

  ## Examples

      iex> {:ok, status} = ApprovalStatus.new("approved")
      iex> ApprovalStatus.approved?(status)
      true

      iex> {:ok, status} = ApprovalStatus.new("draft")
      iex> ApprovalStatus.approved?(status)
      false
  """
  @spec approved?(t()) :: boolean()
  def approved?(%__MODULE__{value: "approved"}), do: true
  def approved?(%__MODULE__{}), do: false

  @doc """
  Checks if the status is rejected.

  ## Parameters
    - status: The ApprovalStatus struct

  ## Returns
    - boolean: true if status is rejected, false otherwise

  ## Examples

      iex> {:ok, status} = ApprovalStatus.new("rejected")
      iex> ApprovalStatus.rejected?(status)
      true

      iex> {:ok, status} = ApprovalStatus.new("approved")
      iex> ApprovalStatus.rejected?(status)
      false
  """
  @spec rejected?(t()) :: boolean()
  def rejected?(%__MODULE__{value: "rejected"}), do: true
  def rejected?(%__MODULE__{}), do: false

  @doc """
  Checks if the status is archived.

  ## Parameters
    - status: The ApprovalStatus struct

  ## Returns
    - boolean: true if status is archived, false otherwise

  ## Examples

      iex> {:ok, status} = ApprovalStatus.new("archived")
      iex> ApprovalStatus.archived?(status)
      true

      iex> {:ok, status} = ApprovalStatus.new("approved")
      iex> ApprovalStatus.archived?(status)
      false
  """
  @spec archived?(t()) :: boolean()
  def archived?(%__MODULE__{value: "archived"}), do: true
  def archived?(%__MODULE__{}), do: false

  @doc """
  Checks if a transition from one status to another is allowed.

  Transition Rules:
  - draft → pending_approval, archived
  - pending_approval → approved, rejected, draft
  - approved → archived
  - rejected → draft, archived
  - archived → (no transitions, terminal state)
  - Any status can stay in same status

  ## Parameters
    - from: The current ApprovalStatus struct
    - to: The target ApprovalStatus struct

  ## Returns
    - boolean: true if transition is allowed, false otherwise

  ## Examples

      iex> {:ok, from} = ApprovalStatus.new("draft")
      iex> {:ok, to} = ApprovalStatus.new("pending_approval")
      iex> ApprovalStatus.can_transition_to?(from, to)
      true

      iex> {:ok, from} = ApprovalStatus.new("draft")
      iex> {:ok, to} = ApprovalStatus.new("approved")
      iex> ApprovalStatus.can_transition_to?(from, to)
      false

      iex> {:ok, from} = ApprovalStatus.new("archived")
      iex> {:ok, to} = ApprovalStatus.new("draft")
      iex> ApprovalStatus.can_transition_to?(from, to)
      false

      iex> {:ok, status} = ApprovalStatus.new("draft")
      iex> ApprovalStatus.can_transition_to?(status, status)
      true
  """
  @spec can_transition_to?(t(), t()) :: boolean()
  def can_transition_to?(%__MODULE__{value: from_value}, %__MODULE__{value: to_value}) do
    # Can always stay in same status
    if from_value == to_value do
      true
    else
      allowed_transitions = Map.get(@transition_rules, from_value, [])
      to_value in allowed_transitions
    end
  end

  @doc """
  Checks if programs with this status should be publicly visible.

  Only approved programs are publicly visible.
  All other statuses (draft, pending_approval, rejected, archived) are not public.

  ## Parameters
    - status: The ApprovalStatus struct

  ## Returns
    - boolean: true if status allows public visibility, false otherwise

  ## Examples

      iex> {:ok, status} = ApprovalStatus.new("approved")
      iex> ApprovalStatus.publicly_visible?(status)
      true

      iex> {:ok, status} = ApprovalStatus.new("draft")
      iex> ApprovalStatus.publicly_visible?(status)
      false

      iex> {:ok, status} = ApprovalStatus.new("archived")
      iex> ApprovalStatus.publicly_visible?(status)
      false
  """
  @spec publicly_visible?(t()) :: boolean()
  def publicly_visible?(%__MODULE__{value: "approved"}), do: true
  def publicly_visible?(%__MODULE__{}), do: false
end
