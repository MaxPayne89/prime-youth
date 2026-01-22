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

  alias KlassHero.Enrollment.Application.UseCases.CalculateEnrollmentFees
  alias KlassHero.Enrollment.Application.UseCases.CountMonthlyBookings
  alias KlassHero.Enrollment.Application.UseCases.CreateEnrollment
  alias KlassHero.Enrollment.Application.UseCases.GetBookingUsageInfo
  alias KlassHero.Enrollment.Application.UseCases.GetEnrollment
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
end
