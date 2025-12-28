defmodule PrimeYouthWeb.ErrorIds do
  @moduledoc """
  Centralized error IDs for tracking, logging, and support correlation.

  Error IDs use dotted notation: `context.domain.action.type`

  ## Error ID Ranges by Bounded Context

  - `program.*` - Program Catalog context errors
  - `parenting.*` - Parenting context errors
  - `providing.*` - Providing context errors
  - `attendance.*` - Attendance context errors (sessions and records)
  - `auth.*` - Authentication context errors (future)
  - `enrollment.*` - Enrollment context errors (future)
  - `family.*` - Family Management context errors (future)
  - `progress.*` - Progress Tracking context errors (future)
  - `review.*` - Review & Rating context errors (future)

  ## Usage

  Error IDs are used in structured logging for correlation and debugging.
  They are NOT displayed to end users in flash messages.

  ### Logging Example

      Logger.error("Database connection failed",
        error_id: ErrorIds.program_list_connection_error(),
        user_id: user.id,
        context: "mount"
      )

  ### User Message Example (NO error ID)

      put_flash(socket, :error, "Connection lost. Please try again.")

  """

  # Program Catalog Context Errors

  @doc """
  Database connection error when listing programs.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def program_list_connection_error, do: "program.catalog.list.connection_error"

  @doc """
  Database query error when listing programs.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def program_list_query_error, do: "program.catalog.list.query_error"

  @doc """
  Generic/unexpected error when listing programs.
  Fallback for errors that don't fit other categories.
  """
  def program_list_generic_error, do: "program.catalog.list.generic_error"

  @doc """
  Program not found when attempting to retrieve by ID.
  """
  def program_not_found, do: "program.catalog.detail.not_found"

  @doc """
  Error converting program price from Decimal to float for UI display.
  """
  def program_price_conversion_error, do: "program.catalog.display.price_conversion_error"

  @doc """
  Error parsing age range format when filtering programs.
  """
  def program_age_filter_error, do: "program.catalog.filter.age_parse_error"

  @doc """
  Database connection error when retrieving a program by ID.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def program_get_connection_error, do: "program.catalog.get.connection_error"

  @doc """
  Database query error when retrieving a program by ID.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def program_get_query_error, do: "program.catalog.get.query_error"

  @doc """
  Generic/unexpected error when retrieving a program by ID.
  Fallback for errors that don't fit other categories.
  """
  def program_get_generic_error, do: "program.catalog.get.generic_error"

  @doc """
  Invalid cursor format when paginating programs.
  Indicates cursor decoding/validation failure.
  """
  def program_pagination_invalid_cursor, do: "program.catalog.paginate.invalid_cursor"

  @doc """
  Database connection error when paginating programs.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def program_pagination_connection_error, do: "program.catalog.paginate.connection_error"

  @doc """
  Database query error when paginating programs.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def program_pagination_query_error, do: "program.catalog.paginate.query_error"

  @doc """
  Generic/unexpected error when paginating programs.
  Fallback for errors that don't fit other categories.
  """
  def program_pagination_generic_error, do: "program.catalog.paginate.generic_error"

  @doc """
  Generic error during pagination operation.
  Used when specific error type cannot be determined.
  """
  def program_pagination_error, do: "program.catalog.paginate.error"

  @doc """
  Program update failed due to concurrent modification (optimistic lock conflict).
  Indicates the record was modified by another process since it was loaded.
  """
  def program_update_stale_entry_error, do: "program.catalog.update.stale_entry_error"

  @doc """
  Program update failed due to constraint violation.
  Indicates data validation failure at the database level.
  """
  def program_update_constraint_violation, do: "program.catalog.update.constraint_violation"

  @doc """
  Database connection error when updating a program.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def program_update_connection_error, do: "program.catalog.update.connection_error"

  @doc """
  Database query error when updating a program.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def program_update_query_error, do: "program.catalog.update.query_error"

  @doc """
  Generic/unexpected error when updating a program.
  Fallback for errors that don't fit other categories.
  """
  def program_update_generic_error, do: "program.catalog.update.generic_error"

  @doc """
  Program not found when attempting to update.
  The program ID does not exist in the database.
  """
  def program_update_not_found, do: "program.catalog.update.not_found"

  # Parenting Context Errors

  @doc """
  Database connection error when creating a parent profile.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def parent_create_connection_error, do: "parenting.profile.create.connection_error"

  @doc """
  Database query error when creating a parent profile.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def parent_create_query_error, do: "parenting.profile.create.query_error"

  @doc """
  Generic/unexpected error when creating a parent profile.
  Fallback for errors that don't fit other categories.
  """
  def parent_create_generic_error, do: "parenting.profile.create.generic_error"

  @doc """
  Database connection error when retrieving a parent profile by identity ID.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def parent_get_connection_error, do: "parenting.profile.get.connection_error"

  @doc """
  Database query error when retrieving a parent profile by identity ID.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def parent_get_query_error, do: "parenting.profile.get.query_error"

  @doc """
  Generic/unexpected error when retrieving a parent profile by identity ID.
  Fallback for errors that don't fit other categories.
  """
  def parent_get_generic_error, do: "parenting.profile.get.generic_error"

  @doc """
  Database connection error when checking if parent profile exists.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def parent_exists_connection_error, do: "parenting.profile.exists.connection_error"

  @doc """
  Database query error when checking if parent profile exists.
  Indicates SQL syntax error or schema mismatch.
  """
  def parent_exists_query_error, do: "parenting.profile.exists.query_error"

  @doc """
  Generic/unexpected error when checking if parent profile exists.
  Fallback for errors that don't fit other categories.
  """
  def parent_exists_generic_error, do: "parenting.profile.exists.generic_error"

  # Providing Context Errors

  @doc """
  Database connection error when creating a provider profile.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def provider_create_connection_error, do: "providing.profile.create.connection_error"

  @doc """
  Database query error when creating a provider profile.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def provider_create_query_error, do: "providing.profile.create.query_error"

  @doc """
  Generic/unexpected error when creating a provider profile.
  Fallback for errors that don't fit other categories.
  """
  def provider_create_generic_error, do: "providing.profile.create.generic_error"

  @doc """
  Database connection error when retrieving a provider profile by identity ID.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def provider_get_connection_error, do: "providing.profile.get.connection_error"

  @doc """
  Database query error when retrieving a provider profile by identity ID.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def provider_get_query_error, do: "providing.profile.get.query_error"

  @doc """
  Generic/unexpected error when retrieving a provider profile by identity ID.
  Fallback for errors that don't fit other categories.
  """
  def provider_get_generic_error, do: "providing.profile.get.generic_error"

  @doc """
  Database connection error when checking if provider profile exists.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def provider_exists_connection_error, do: "providing.profile.exists.connection_error"

  @doc """
  Database query error when checking if provider profile exists.
  Indicates SQL syntax error or schema mismatch.
  """
  def provider_exists_query_error, do: "providing.profile.exists.query_error"

  @doc """
  Generic/unexpected error when checking if provider profile exists.
  Fallback for errors that don't fit other categories.
  """
  def provider_exists_generic_error, do: "providing.profile.exists.generic_error"

  # Attendance Context Errors - Session

  @doc """
  Database connection error when creating a session.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def session_create_connection_error, do: "attendance.session.create.connection_error"

  @doc """
  Database query error when creating a session.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def session_create_query_error, do: "attendance.session.create.query_error"

  @doc """
  Generic/unexpected error when creating a session.
  Fallback for errors that don't fit other categories.
  """
  def session_create_generic_error, do: "attendance.session.create.generic_error"

  @doc """
  Database connection error when retrieving a session by ID.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def session_get_connection_error, do: "attendance.session.get.connection_error"

  @doc """
  Database query error when retrieving a session by ID.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def session_get_query_error, do: "attendance.session.get.query_error"

  @doc """
  Generic/unexpected error when retrieving a session by ID.
  Fallback for errors that don't fit other categories.
  """
  def session_get_generic_error, do: "attendance.session.get.generic_error"

  @doc """
  Database connection error when listing sessions.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def session_list_connection_error, do: "attendance.session.list.connection_error"

  @doc """
  Database query error when listing sessions.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def session_list_query_error, do: "attendance.session.list.query_error"

  @doc """
  Generic/unexpected error when listing sessions.
  Fallback for errors that don't fit other categories.
  """
  def session_list_generic_error, do: "attendance.session.list.generic_error"

  @doc """
  Session update failed due to constraint violation.
  Indicates data validation failure at the database level.
  """
  def session_update_constraint_violation, do: "attendance.session.update.constraint_violation"

  @doc """
  Database connection error when updating a session.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def session_update_connection_error, do: "attendance.session.update.connection_error"

  @doc """
  Database query error when updating a session.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def session_update_query_error, do: "attendance.session.update.query_error"

  @doc """
  Generic/unexpected error when updating a session.
  Fallback for errors that don't fit other categories.
  """
  def session_update_generic_error, do: "attendance.session.update.generic_error"

  @doc """
  Optimistic lock conflict when updating a session.
  Record was modified by another process since it was loaded.
  """
  def session_update_stale_error, do: "attendance.session.update.stale"

  @doc """
  Duplicate session error - session already exists for the same program/date/time.
  """
  def session_duplicate_error, do: "attendance.session.create.duplicate"

  @doc """
  Session validation error - changeset validation failed.
  """
  def session_validation_error, do: "attendance.session.validation.error"

  # Attendance Context Errors - Attendance Record

  @doc """
  Database connection error when creating an attendance record.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def attendance_create_connection_error, do: "attendance.record.create.connection_error"

  @doc """
  Database query error when creating an attendance record.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def attendance_create_query_error, do: "attendance.record.create.query_error"

  @doc """
  Generic/unexpected error when creating an attendance record.
  Fallback for errors that don't fit other categories.
  """
  def attendance_create_generic_error, do: "attendance.record.create.generic_error"

  @doc """
  Database connection error when retrieving an attendance record.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def attendance_get_connection_error, do: "attendance.record.get.connection_error"

  @doc """
  Database query error when retrieving an attendance record.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def attendance_get_query_error, do: "attendance.record.get.query_error"

  @doc """
  Generic/unexpected error when retrieving an attendance record.
  Fallback for errors that don't fit other categories.
  """
  def attendance_get_generic_error, do: "attendance.record.get.generic_error"

  @doc """
  Attendance update failed due to concurrent modification (optimistic lock conflict).
  Indicates the record was modified by another process since it was loaded.
  """
  def attendance_update_stale_error, do: "attendance.record.update.stale_entry"

  @doc """
  Attendance update failed due to constraint violation.
  Indicates data validation failure at the database level.
  """
  def attendance_update_constraint_violation, do: "attendance.record.update.constraint_violation"

  @doc """
  Database connection error when updating an attendance record.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def attendance_update_connection_error, do: "attendance.record.update.connection_error"

  @doc """
  Database query error when updating an attendance record.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def attendance_update_query_error, do: "attendance.record.update.query_error"

  @doc """
  Generic/unexpected error when updating an attendance record.
  Fallback for errors that don't fit other categories.
  """
  def attendance_update_generic_error, do: "attendance.record.update.generic_error"

  @doc """
  Database connection error when listing attendance records.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def attendance_list_connection_error, do: "attendance.record.list.connection_error"

  @doc """
  Database query error when listing attendance records.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def attendance_list_query_error, do: "attendance.record.list.query_error"

  @doc """
  Generic/unexpected error when listing attendance records.
  Fallback for errors that don't fit other categories.
  """
  def attendance_list_generic_error, do: "attendance.record.list.generic_error"

  @doc """
  Batch attendance submission failed.
  """
  def attendance_batch_error, do: "attendance.record.batch.error"

  @doc """
  Batch attendance failed due to concurrent modification (optimistic lock conflict).
  """
  def attendance_batch_stale_error, do: "attendance.record.batch.stale_entry"

  @doc """
  Database connection error during batch attendance submission.
  """
  def attendance_batch_connection_error, do: "attendance.record.batch.connection_error"

  @doc """
  Database query error during batch attendance submission.
  """
  def attendance_batch_query_error, do: "attendance.record.batch.query_error"

  @doc """
  Generic/unexpected error during batch attendance submission.
  """
  def attendance_batch_generic_error, do: "attendance.record.batch.generic_error"

  @doc """
  Duplicate attendance record error - record already exists for session/child combination.
  """
  def attendance_duplicate_error, do: "attendance.record.create.duplicate"

  @doc """
  Attendance validation error - changeset validation failed.
  """
  def attendance_validation_error, do: "attendance.record.validation.error"

  # Family Management Context Errors - Child

  @doc """
  Database connection error when retrieving a child by ID.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def child_get_connection_error, do: "family.child.get.connection_error"

  @doc """
  Database query error when retrieving a child by ID.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def child_get_query_error, do: "family.child.get.query_error"

  @doc """
  Generic/unexpected error when retrieving a child by ID.
  Fallback for errors that don't fit other categories.
  """
  def child_get_generic_error, do: "family.child.get.generic_error"

  @doc """
  Database connection error when creating a child.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def child_create_connection_error, do: "family.child.create.connection_error"

  @doc """
  Database query error when creating a child.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def child_create_query_error, do: "family.child.create.query_error"

  @doc """
  Generic/unexpected error when creating a child.
  Fallback for errors that don't fit other categories.
  """
  def child_create_generic_error, do: "family.child.create.generic_error"

  @doc """
  Database connection error when listing children by parent.
  Indicates transient network/connection issue that may resolve on retry.
  """
  def child_list_connection_error, do: "family.child.list.connection_error"

  @doc """
  Database query error when listing children by parent.
  Indicates SQL syntax error, constraint violation, or schema mismatch.
  """
  def child_list_query_error, do: "family.child.list.query_error"

  @doc """
  Generic/unexpected error when listing children by parent.
  Fallback for errors that don't fit other categories.
  """
  def child_list_generic_error, do: "family.child.list.generic_error"
end
