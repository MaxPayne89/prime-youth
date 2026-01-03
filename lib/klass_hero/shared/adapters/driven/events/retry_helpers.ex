defmodule KlassHero.Shared.Adapters.Driven.Events.RetryHelpers do
  @moduledoc """
  Shared retry logic with error classification and exponential backoff.

  This module provides intelligent retry strategies for event-driven operations,
  distinguishing between transient (retryable) and permanent (non-retryable) errors.

  ## Error Classification

  **Retryable Errors** (with backoff):
  - `:database_connection_error` - Network/connection issues that may resolve

  **Permanent Errors** (no retry):
  - `:duplicate_identity` - Profile already exists (idempotent - returns `:ok`)
  - `:invalid_identity` - Identity doesn't exist
  - `:database_query_error` - SQL/schema/validation errors
  - `:database_unavailable` - Generic/unexpected database errors
  - `{:validation_error, _}` - Domain validation failures

  ## Examples

      # Basic usage with default 100ms backoff
      operation = fn -> create_profile(%{identity_id: "123"}) end
      context = %{
        operation_name: "create parent profile",
        aggregate_id: "user-123"
      }

      RetryHelpers.retry_with_backoff(operation, context)
      # => :ok | {:ok, result} | {:error, reason}

      # Custom backoff timing
      context = %{
        operation_name: "create provider profile",
        aggregate_id: "user-456",
        backoff_ms: 200
      }

      RetryHelpers.retry_with_backoff(operation, context)
  """

  require Logger

  @default_backoff_ms 100

  @doc """
  Executes an operation with intelligent retry logic and error classification.

  ## Parameters

  - `operation` - A zero-arity function that returns `:ok`, `{:ok, result}`, or `{:error, reason}`
  - `context` - A map containing:
    - `:operation_name` (required) - Human-readable operation name for logging
    - `:aggregate_id` (required) - Identifier for the aggregate being operated on
    - `:backoff_ms` (optional) - Milliseconds to wait before retry (default: 100)

  ## Return Values

  - `:ok` - Operation succeeded
  - `{:ok, result}` - Operation succeeded with result
  - `{:error, reason}` - Operation failed (after retry if applicable)

  ## Retry Behavior

  1. **First Attempt**: Execute operation immediately
  2. **Transient Errors**: Wait `backoff_ms` and retry once
  3. **Permanent Errors**: Return immediately without retry
  4. **Duplicate Identity**: Treated as success (idempotent operation)

  All retry attempts are logged with unique error IDs for correlation.

  ## Examples

      # Success on first attempt
      operation = fn -> {:ok, %Parent{}} end
      retry_with_backoff(operation, context)
      # => {:ok, %Parent{}}

      # Transient error with successful retry
      attempts = :counters.new(1, [])
      operation = fn ->
        case :counters.get(attempts, 1) do
          0 ->
            :counters.add(attempts, 1, 1)
            {:error, :database_connection_error}
          _ ->
            {:ok, %Parent{}}
        end
      end
      retry_with_backoff(operation, context)
      # => {:ok, %Parent{}} (after 100ms retry)

      # Permanent error (no retry)
      operation = fn -> {:error, :invalid_identity} end
      retry_with_backoff(operation, context)
      # => {:error, :invalid_identity}

      # Duplicate identity (idempotent)
      operation = fn -> {:error, :duplicate_identity} end
      retry_with_backoff(operation, context)
      # => :ok
  """
  @spec retry_with_backoff(
          operation :: (-> :ok | {:ok, term()} | {:error, atom() | {atom(), term()}}),
          context :: map()
        ) :: :ok | {:ok, term()} | {:error, atom() | {atom(), term()}}
  def retry_with_backoff(operation, context) when is_function(operation, 0) and is_map(context) do
    backoff_ms = Map.get(context, :backoff_ms, @default_backoff_ms)

    case operation.() do
      :ok ->
        :ok

      {:ok, result} ->
        {:ok, result}

      {:error, :duplicate_identity} ->
        log_duplicate_identity(context)
        :ok

      {:error, reason} = error ->
        if retryable_error?(reason) do
          log_retry_attempt(reason, context)
          Process.sleep(backoff_ms)
          handle_retry(operation, context, error)
        else
          log_permanent_error(reason, context)
          error
        end
    end
  end

  # Handle the retry attempt
  defp handle_retry(operation, context, original_error) do
    case operation.() do
      :ok ->
        log_retry_success(context)
        :ok

      {:ok, result} ->
        log_retry_success(context)
        {:ok, result}

      {:error, :duplicate_identity} ->
        log_duplicate_identity(context)
        :ok

      {:error, _reason} ->
        log_retry_failure(context)
        original_error
    end
  end

  # Classify errors as retryable or permanent

  @doc """
  Determines if an error is transient and should be retried.

  Only database connection errors are considered transient and worth retrying.
  """
  @spec retryable_error?(atom() | {atom(), term()}) :: boolean()
  def retryable_error?(:database_connection_error), do: true
  def retryable_error?(_), do: false

  @doc """
  Determines if an error is permanent and should not be retried.
  """
  @spec permanent_error?(atom() | {atom(), term()}) :: boolean()
  def permanent_error?(:duplicate_identity), do: true
  def permanent_error?(:invalid_identity), do: true
  def permanent_error?(:database_query_error), do: true
  def permanent_error?(:database_unavailable), do: true
  def permanent_error?({:validation_error, _}), do: true
  def permanent_error?(_), do: false

  # Logging functions with error IDs for correlation

  defp log_retry_attempt(reason, context) do
    error_id = generate_error_id()

    Logger.warning(
      "[#{error_id}] [RetryHelpers] Retrying #{context.operation_name} " <>
        "for aggregate #{context.aggregate_id} after transient error: #{inspect(reason)}"
    )
  end

  defp log_retry_success(context) do
    Logger.info(
      "[RetryHelpers] Successfully #{context.operation_name} " <>
        "for aggregate #{context.aggregate_id} on retry"
    )
  end

  defp log_retry_failure(context) do
    error_id = generate_error_id()

    Logger.error(
      "[#{error_id}] [RetryHelpers] Failed to #{context.operation_name} " <>
        "for aggregate #{context.aggregate_id} after retry"
    )
  end

  defp log_permanent_error(reason, context) do
    error_id = generate_error_id()

    Logger.error(
      "[#{error_id}] [RetryHelpers] Permanent error during #{context.operation_name} " <>
        "for aggregate #{context.aggregate_id}: #{inspect(reason)} (no retry)"
    )
  end

  defp log_duplicate_identity(context) do
    Logger.debug(
      "[RetryHelpers] #{context.operation_name} for aggregate #{context.aggregate_id}: " <>
        "duplicate identity (idempotent - treated as success)"
    )
  end

  defp generate_error_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
end
