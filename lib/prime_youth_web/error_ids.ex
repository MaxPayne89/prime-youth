defmodule PrimeYouthWeb.ErrorIds do
  @moduledoc """
  Centralized error IDs for tracking, logging, and support correlation.

  Error IDs use dotted notation: `context.domain.action.type`

  ## Error ID Ranges by Bounded Context

  - `program.*` - Program Catalog context errors
  - `attendance.*` - Attendance context errors (sessions and records)

  ## Usage

  Error IDs are used in structured logging for correlation and debugging.
  They are NOT displayed to end users in flash messages.

  ### Logging Example

      Logger.warning("Program update conflict",
        error_id: ErrorIds.program_update_stale_entry_error(),
        program_id: program.id
      )

  ## Philosophy

  Only domain-level errors that represent expected business scenarios are tracked.
  Infrastructure errors (connection failures, query errors) should crash and be
  handled by the supervision tree - they don't need explicit error IDs.
  """

  # Program Catalog Context - Domain Errors

  @doc "Program not found when attempting to retrieve by ID."
  def program_not_found, do: "program.catalog.detail.not_found"

  @doc "Invalid cursor format when paginating programs."
  def program_pagination_invalid_cursor, do: "program.catalog.paginate.invalid_cursor"

  @doc "Program update failed due to concurrent modification (optimistic lock conflict)."
  def program_update_stale_entry_error, do: "program.catalog.update.stale_entry_error"

  @doc "Program update failed due to constraint violation."
  def program_update_constraint_violation, do: "program.catalog.update.constraint_violation"

  @doc "Program update failed - program not found."
  def program_update_not_found, do: "program.catalog.update.not_found"

  # Attendance Context - Session Domain Errors

  @doc "Session update failed due to concurrent modification (optimistic lock conflict)."
  def session_update_stale_error, do: "attendance.session.update.stale"

  @doc "Session update failed due to constraint violation."
  def session_update_constraint_violation, do: "attendance.session.update.constraint_violation"

  @doc "Duplicate session error - session already exists for the same program/date/time."
  def session_duplicate_error, do: "attendance.session.create.duplicate"

  @doc "Session validation error - changeset validation failed."
  def session_validation_error, do: "attendance.session.validation.error"

  # Attendance Context - Attendance Record Domain Errors

  @doc "Attendance update failed due to concurrent modification (optimistic lock conflict)."
  def attendance_update_stale_error, do: "attendance.record.update.stale_entry"

  @doc "Attendance update failed due to constraint violation."
  def attendance_update_constraint_violation, do: "attendance.record.update.constraint_violation"

  @doc "Duplicate attendance record error - record already exists for session/child combination."
  def attendance_duplicate_error, do: "attendance.record.create.duplicate"

  @doc "Attendance validation error - changeset validation failed."
  def attendance_validation_error, do: "attendance.record.validation.error"

  # Parenting Context - Domain Errors

  @doc "Duplicate parent profile - identity already has a parent profile."
  def parent_duplicate_identity, do: "parenting.profile.create.duplicate_identity"

  # Providing Context - Domain Errors

  @doc "Duplicate provider profile - identity already has a provider profile."
  def provider_duplicate_identity, do: "providing.profile.create.duplicate_identity"

  # Family Context - Domain Errors

  @doc "Child validation error - changeset validation failed."
  def child_validation_error, do: "family.child.validation.error"
end
