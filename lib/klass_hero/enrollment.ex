defmodule KlassHero.Enrollment do
  @moduledoc """
  Public API for the Enrollment bounded context.

  This module provides the public interface for managing program enrollments,
  including creating enrollments, tracking booking counts for entitlements,
  and retrieving enrollment history.

  ## Usage

      # Create an enrollment
      {:ok, enrollment} = Enrollment.create_enrollment(%{
        program_id: "program-uuid",
        child_id: "child-uuid",
        parent_id: "parent-uuid",
        payment_method: "card",
        subtotal: Decimal.new("45.00"),
        vat_amount: Decimal.new("8.55"),
        total_amount: Decimal.new("53.55")
      })

      # Get an enrollment
      {:ok, enrollment} = Enrollment.get_enrollment("enrollment-uuid")

      # List enrollments for a parent
      enrollments = Enrollment.list_parent_enrollments("parent-uuid")

      # Count monthly bookings (for entitlement enforcement)
      count = Enrollment.count_monthly_bookings("parent-uuid")

  ## Architecture

  This context follows the Ports & Adapters architecture:
  - Public API (this module) → delegates to use cases
  - Use cases (application layer) → orchestrate domain operations
  - Repository ports (domain layer) → define persistence contracts
  - Repository implementations (adapter layer) → implement persistence
  """

  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Entitlements, KlassHero.Family, KlassHero.Shared],
    exports: []

  alias KlassHero.Enrollment.Application.UseCases.CalculateEnrollmentFees
  alias KlassHero.Enrollment.Application.UseCases.CheckEnrollment
  alias KlassHero.Enrollment.Application.UseCases.CheckParticipantEligibility
  alias KlassHero.Enrollment.Application.UseCases.CountMonthlyBookings
  alias KlassHero.Enrollment.Application.UseCases.CreateEnrollment
  alias KlassHero.Enrollment.Application.UseCases.GetBookingUsageInfo
  alias KlassHero.Enrollment.Application.UseCases.GetEnrollment
  alias KlassHero.Enrollment.Application.UseCases.ListEnrolledIdentityIds
  alias KlassHero.Enrollment.Application.UseCases.ListParentEnrollments

  # ============================================================================
  # Enrollment Management Functions
  # ============================================================================

  @doc """
  Creates a new enrollment.

  Required parameters:
  - program_id: UUID of the program
  - child_id: UUID of the child
  - parent_id: UUID of the parent

  Optional parameters:
  - status: Enrollment status (defaults to "pending")
  - enrolled_at: DateTime (defaults to now)
  - subtotal, vat_amount, card_fee_amount, total_amount: Fee amounts
  - payment_method: "card" or "transfer"
  - special_requirements: Special needs text

  Returns:
  - `{:ok, Enrollment.t()}` - Enrollment created successfully
  - `{:error, :duplicate_resource}` - Active enrollment already exists for child/program
  - `{:error, term()}` - Validation or persistence failure
  """
  def create_enrollment(params) when is_map(params) do
    CreateEnrollment.execute(params)
  end

  @doc """
  Retrieves an enrollment by ID.

  Returns:
  - `{:ok, Enrollment.t()}` - Enrollment found
  - `{:error, :not_found}` - No enrollment exists with the given ID
  """
  def get_enrollment(id) when is_binary(id) do
    GetEnrollment.execute(id)
  end

  @doc """
  Lists all enrollments for a parent.

  Returns list of Enrollment.t(), ordered by enrolled_at descending.
  Returns empty list if no enrollments found.
  """
  def list_parent_enrollments(parent_id) when is_binary(parent_id) do
    ListParentEnrollments.execute(parent_id)
  end

  @doc """
  Counts active enrollments for a parent in the current month.

  This is used by the entitlements system to enforce monthly booking limits.
  Only counts enrollments with status 'pending' or 'confirmed'.

  Parameters:
  - parent_id: The parent's ID
  - month: Optional Date representing the month (defaults to current month)

  Returns non-negative integer count.
  """
  def count_monthly_bookings(parent_id, month \\ nil) when is_binary(parent_id) do
    CountMonthlyBookings.execute(parent_id, month)
  end

  @doc """
  Returns booking usage information for a parent.

  This encapsulates the logic for fetching booking limits, current usage,
  and remaining capacity based on the parent's subscription tier.

  ## Parameters

  - `identity_id` - The user's identity ID (from authentication)

  ## Returns

  - `{:ok, info}` with booking usage map containing:
    - `parent_id` - The parent's UUID
    - `tier` - The subscription tier atom
    - `cap` - The monthly booking cap (integer or :unlimited)
    - `used` - Number of bookings used this month
    - `remaining` - Number of bookings remaining (:unlimited or integer)
  - `{:error, :no_parent_profile}` if no parent profile exists
  """
  def get_booking_usage_info(identity_id) when is_binary(identity_id) do
    GetBookingUsageInfo.execute(identity_id)
  end

  # ============================================================================
  # Fee Calculation Functions
  # ============================================================================

  @doc """
  Calculates enrollment fees including VAT and optional card processing fees.

  Parameters:
  - weekly_fee: The weekly program fee
  - registration_fee: One-time registration fee
  - vat_rate: VAT rate as decimal (e.g., 0.19 for 19%)
  - card_fee: Card processing fee amount
  - payment_method: "card" or "transfer"

  Returns:
  - `{:ok, FeeCalculation.t()}` with subtotal, vat_amount, card_fee_amount, and total
  """
  def calculate_fees(params) when is_map(params) do
    CalculateEnrollmentFees.execute(params)
  end

  # ============================================================================
  # Cross-Context Query Functions
  # ============================================================================

  @doc """
  Returns identity IDs of parents with active enrollments in a program.

  Active enrollments are those with status "pending" or "confirmed".
  Used by the Messaging context for program broadcast recipient resolution.

  Returns a distinct list of identity_ids (user IDs).
  """
  @spec list_enrolled_identity_ids(String.t()) :: [String.t()]
  def list_enrolled_identity_ids(program_id) when is_binary(program_id) do
    ListEnrolledIdentityIds.execute(program_id)
  end

  @doc """
  Checks if a parent (identified by identity_id) is actively enrolled in a program.

  Returns true if at least one active enrollment (pending or confirmed) exists.
  """
  @spec enrolled?(String.t(), String.t()) :: boolean()
  def enrolled?(program_id, identity_id) when is_binary(program_id) and is_binary(identity_id) do
    CheckEnrollment.execute(program_id, identity_id)
  end

  # ============================================================================
  # Enrollment Policy Functions
  # ============================================================================

  @doc """
  Creates or updates enrollment capacity policy for a program.

  ## Parameters
  - attrs: Map with :program_id (required), :min_enrollment, :max_enrollment (at least one required)

  ## Returns
  - `{:ok, EnrollmentPolicy.t()}` on success
  - `{:error, term()}` on validation failure
  """
  def set_enrollment_policy(attrs) when is_map(attrs) do
    policy_repo().upsert(attrs)
  end

  @doc """
  Returns the enrollment policy for a program.
  """
  def get_enrollment_policy(program_id) when is_binary(program_id) do
    policy_repo().get_by_program_id(program_id)
  end

  @doc """
  Returns remaining enrollment capacity for a program.

  Fetches the policy and active count, then delegates calculation to the
  domain model (`EnrollmentPolicy.remaining_capacity/2`).

  - `{:ok, non_neg_integer()}` — remaining spots
  - `{:ok, :unlimited}` — no maximum configured
  """
  def remaining_capacity(program_id) when is_binary(program_id) do
    alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

    case policy_repo().get_by_program_id(program_id) do
      {:error, :not_found} ->
        {:ok, :unlimited}

      {:ok, policy} ->
        count = policy_repo().count_active_enrollments(program_id)
        {:ok, EnrollmentPolicy.remaining_capacity(policy, count)}
    end
  end

  @doc """
  Returns remaining capacity for multiple programs in a single batch query.
  Returns a map of `program_id => remaining_count | :unlimited`.
  """
  def get_remaining_capacities(program_ids) when is_list(program_ids) do
    alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

    policies = policy_repo().get_policies_by_program_ids(program_ids)
    active_counts = policy_repo().count_active_enrollments_batch(program_ids)

    Map.new(program_ids, fn id ->
      case Map.get(policies, id) do
        nil ->
          {id, :unlimited}

        policy ->
          count = Map.get(active_counts, id, 0)
          {id, EnrollmentPolicy.remaining_capacity(policy, count)}
      end
    end)
  end

  @doc """
  Returns the count of active (pending/confirmed) enrollments for a program.
  """
  def count_active_enrollments(program_id) when is_binary(program_id) do
    policy_repo().count_active_enrollments(program_id)
  end

  @doc """
  Returns counts of active enrollments for multiple programs in a single batch query.
  Returns a map of `program_id => count`.
  """
  def count_active_enrollments_batch(program_ids) when is_list(program_ids) do
    policy_repo().count_active_enrollments_batch(program_ids)
  end

  @doc """
  Returns a changeset for enrollment policy form validation.

  Used by the provider dashboard to validate capacity fields inline
  before the program is created.
  """
  def new_policy_changeset(attrs \\ %{}) do
    alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema

    EnrollmentPolicySchema.changeset(%EnrollmentPolicySchema{}, attrs)
  end

  defp policy_repo do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollment_policies]
  end

  # ============================================================================
  # Participant Policy Functions
  # ============================================================================

  @doc """
  Checks whether a child is eligible for a program based on participant restrictions.

  Returns `{:ok, :eligible}` when eligible or no policy exists.
  Returns `{:error, :ineligible, reasons}` with human-readable reason list.
  Returns `{:error, :not_found}` when the child does not exist.
  """
  def check_participant_eligibility(program_id, child_id)
      when is_binary(program_id) and is_binary(child_id) do
    CheckParticipantEligibility.execute(program_id, child_id)
  end

  @doc """
  Creates or updates a participant eligibility policy for a program.

  Uses upsert semantics -- if a policy already exists for the program_id, it is updated.
  """
  def set_participant_policy(attrs) when is_map(attrs) do
    participant_policy_repo().upsert(attrs)
  end

  @doc """
  Returns the participant policy for a program.
  """
  def get_participant_policy(program_id) when is_binary(program_id) do
    participant_policy_repo().get_by_program_id(program_id)
  end

  @doc """
  Returns a changeset for participant policy form validation.

  Used by the provider dashboard to validate eligibility restriction fields
  inline before the program is created.
  """
  def new_participant_policy_changeset(attrs \\ %{}) do
    alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.ParticipantPolicySchema

    ParticipantPolicySchema.changeset(%ParticipantPolicySchema{}, attrs)
  end

  defp participant_policy_repo do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_participant_policies]
  end
end
