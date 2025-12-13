defmodule PrimeYouthWeb.ErrorIds do
  @moduledoc """
  Centralized error IDs for tracking, logging, and support correlation.

  Error IDs use dotted notation: `context.domain.action.type`

  ## Error ID Ranges by Bounded Context

  - `program.*` - Program Catalog context errors
  - `parenting.*` - Parenting context errors
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
end
