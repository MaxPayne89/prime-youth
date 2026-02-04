defmodule KlassHero.Shared.Adapters.Driven.Events.RetryHelpersTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.RetryHelpers

  @default_context %{
    operation_name: "test operation",
    aggregate_id: "test-123"
  }

  describe "retry_with_backoff/2" do
    test "returns :ok when operation succeeds on first attempt" do
      operation = fn -> :ok end

      assert :ok = RetryHelpers.retry_with_backoff(operation, @default_context)
    end

    test "returns {:ok, result} when operation succeeds on first attempt" do
      operation = fn -> {:ok, %{id: "123"}} end

      assert {:ok, %{id: "123"}} = RetryHelpers.retry_with_backoff(operation, @default_context)
    end

    test "returns :ok for duplicate resource error (idempotent)" do
      operation = fn -> {:error, :duplicate_resource} end

      assert :ok = RetryHelpers.retry_with_backoff(operation, @default_context)
    end

    test "retries transient error once with default 100ms backoff" do
      # Use an agent to track call count
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        count = Agent.get_and_update(counter, fn count -> {count, count + 1} end)

        case count do
          0 -> {:error, :database_connection_error}
          1 -> {:ok, %{success: true}}
        end
      end

      start_time = System.monotonic_time(:millisecond)

      assert {:ok, %{success: true}} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      elapsed_time = System.monotonic_time(:millisecond) - start_time

      # Verify retry occurred (should take at least 100ms)
      assert elapsed_time >= 100
      assert elapsed_time < 200

      # Verify operation was called twice
      assert Agent.get(counter, & &1) == 2

      Agent.stop(counter)
    end

    test "retries transient error once with custom backoff" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        count = Agent.get_and_update(counter, fn count -> {count, count + 1} end)

        case count do
          0 -> {:error, :database_connection_error}
          1 -> {:ok, %{success: true}}
        end
      end

      context = Map.put(@default_context, :backoff_ms, 50)

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, %{success: true}} = RetryHelpers.retry_with_backoff(operation, context)
      elapsed_time = System.monotonic_time(:millisecond) - start_time

      # Verify custom backoff was used (should take at least 50ms but less than 100ms)
      assert elapsed_time >= 50
      assert elapsed_time < 150

      Agent.stop(counter)
    end

    test "returns original error when retry fails" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, :database_connection_error}
      end

      assert {:error, :database_connection_error} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      # Verify operation was called twice (original + retry)
      assert Agent.get(counter, & &1) == 2

      Agent.stop(counter)
    end

    test "does not retry permanent errors - resource_not_found" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, :resource_not_found}
      end

      assert {:error, :resource_not_found} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      # Verify operation was called only once (no retry)
      assert Agent.get(counter, & &1) == 1

      Agent.stop(counter)
    end

    test "does not retry permanent errors - database_query_error" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, :database_query_error}
      end

      assert {:error, :database_query_error} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      assert Agent.get(counter, & &1) == 1

      Agent.stop(counter)
    end

    test "does not retry permanent errors - database_unavailable" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, :database_unavailable}
      end

      assert {:error, :database_unavailable} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      assert Agent.get(counter, & &1) == 1

      Agent.stop(counter)
    end

    test "does not retry validation errors" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, {:validation_error, ["Identity ID cannot be empty"]}}
      end

      assert {:error, {:validation_error, ["Identity ID cannot be empty"]}} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      assert Agent.get(counter, & &1) == 1

      Agent.stop(counter)
    end

    test "handles retry success after transient error" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        count = Agent.get_and_update(counter, fn count -> {count, count + 1} end)

        case count do
          0 -> {:error, :database_connection_error}
          1 -> :ok
        end
      end

      assert :ok = RetryHelpers.retry_with_backoff(operation, @default_context)
      assert Agent.get(counter, & &1) == 2

      Agent.stop(counter)
    end

    test "treats duplicate resource as success on retry" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        count = Agent.get_and_update(counter, fn count -> {count, count + 1} end)

        case count do
          0 -> {:error, :database_connection_error}
          1 -> {:error, :duplicate_resource}
        end
      end

      assert :ok = RetryHelpers.retry_with_backoff(operation, @default_context)
      assert Agent.get(counter, & &1) == 2

      Agent.stop(counter)
    end
  end

  describe "retryable_error?/1" do
    test "returns true for database_connection_error" do
      assert RetryHelpers.retryable_error?(:database_connection_error)
    end

    test "returns false for all other errors" do
      refute RetryHelpers.retryable_error?(:duplicate_resource)
      refute RetryHelpers.retryable_error?(:resource_not_found)
      refute RetryHelpers.retryable_error?(:database_query_error)
      refute RetryHelpers.retryable_error?(:database_unavailable)
      refute RetryHelpers.retryable_error?({:validation_error, []})
      refute RetryHelpers.retryable_error?(:unknown_error)
    end

    test "delegates through step-tagged tuple with retryable inner reason" do
      assert RetryHelpers.retryable_error?({:anonymize_messages, :database_connection_error})
    end

    test "delegates through step-tagged tuple with non-retryable inner reason" do
      refute RetryHelpers.retryable_error?({:mark_as_left, :database_query_error})
    end
  end

  describe "permanent_error?/1" do
    test "returns true for duplicate_resource" do
      assert RetryHelpers.permanent_error?(:duplicate_resource)
    end

    test "returns true for resource_not_found" do
      assert RetryHelpers.permanent_error?(:resource_not_found)
    end

    test "returns true for database_query_error" do
      assert RetryHelpers.permanent_error?(:database_query_error)
    end

    test "returns true for database_unavailable" do
      assert RetryHelpers.permanent_error?(:database_unavailable)
    end

    test "returns true for validation_error tuple" do
      assert RetryHelpers.permanent_error?({:validation_error, ["error"]})
    end

    test "returns false for database_connection_error" do
      refute RetryHelpers.permanent_error?(:database_connection_error)
    end

    test "returns false for unknown errors" do
      refute RetryHelpers.permanent_error?(:unknown_error)
    end

    test "delegates through step-tagged tuple with permanent inner reason" do
      assert RetryHelpers.permanent_error?({:anonymize_messages, :database_query_error})
    end

    test "delegates through step-tagged tuple with non-permanent inner reason" do
      refute RetryHelpers.permanent_error?({:mark_as_left, :database_connection_error})
    end
  end

  describe "retry_with_backoff/2 with step-tagged errors" do
    test "retries tagged retryable error and succeeds on 2nd attempt" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        count = Agent.get_and_update(counter, fn count -> {count, count + 1} end)

        case count do
          0 -> {:error, {:anonymize_messages, :database_connection_error}}
          1 -> {:ok, %{success: true}}
        end
      end

      assert {:ok, %{success: true}} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      assert Agent.get(counter, & &1) == 2

      Agent.stop(counter)
    end

    test "does not retry tagged permanent error" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      operation = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, {:mark_as_left, :database_query_error}}
      end

      assert {:error, {:mark_as_left, :database_query_error}} =
               RetryHelpers.retry_with_backoff(operation, @default_context)

      assert Agent.get(counter, & &1) == 1

      Agent.stop(counter)
    end
  end
end
