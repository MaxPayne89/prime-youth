defmodule PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository do
  @moduledoc """
  Repository implementation for listing programs from the database.

  Implements the ForListingPrograms port with:
  - Automatic retry logic (3 attempts with exponential backoff)
  - Domain entity mapping via ProgramMapper
  - Comprehensive logging for database operations

  Data integrity is enforced at the database level through NOT NULL constraints.
  """

  @behaviour PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms

  import Ecto.Query

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapper
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.Repo

  require Logger

  @max_retries 3
  @initial_delay_ms 0
  @retry_delays [100, 300]

  @impl true
  @doc """
  Lists all programs from the database.

  Programs are ordered by title in ascending order for consistent display.
  Data integrity is enforced at the database level through NOT NULL constraints
  on all required fields (title, description, schedule, age_range, price, pricing_period).

  Returns:
  - {:ok, [Program.t()]} on success (empty list if no programs exist)
  - {:error, :database_unavailable} after 3 failed retry attempts

  ## Examples

      iex> ProgramRepository.list_all_programs()
      {:ok, [%Program{title: "Art Adventures", ...}, %Program{title: "Soccer Camp", ...}]}

      iex> ProgramRepository.list_all_programs()
      {:ok, []}  # No programs in database

      iex> ProgramRepository.list_all_programs()
      {:error, :database_unavailable}  # Database connection failed after retries

  """
  @spec list_all_programs() :: {:ok, [Program.t()]} | {:error, :database_unavailable}
  def list_all_programs do
    Logger.info("[ProgramRepository] Starting list_all_programs query")

    query = from p in ProgramSchema, order_by: [asc: p.title]

    case execute_with_retry(query, 1) do
      {:ok, schemas} ->
        programs = ProgramMapper.to_domain_list(schemas)

        Logger.info(
          "[ProgramRepository] Successfully retrieved #{length(programs)} programs from database"
        )

        {:ok, programs}

      {:error, reason} ->
        Logger.error(
          "[ProgramRepository] Failed to retrieve programs after #{@max_retries} attempts: #{inspect(reason)}"
        )

        {:error, :database_unavailable}
    end
  end

  # Private helper: Execute query with retry logic
  @spec execute_with_retry(Ecto.Query.t(), pos_integer()) ::
          {:ok, [ProgramSchema.t()]} | {:error, any()}
  defp execute_with_retry(query, attempt) when attempt <= @max_retries do
    Logger.debug("[ProgramRepository] Query attempt #{attempt}/#{@max_retries}")

    try do
      schemas = Repo.all(query)
      {:ok, schemas}
    rescue
      error ->
        Logger.warning(
          "[ProgramRepository] Query failed on attempt #{attempt}/#{@max_retries}: #{inspect(error)}"
        )

        if attempt < @max_retries do
          delay = get_retry_delay(attempt)
          Logger.debug("[ProgramRepository] Retrying in #{delay}ms...")
          Process.sleep(delay)
          execute_with_retry(query, attempt + 1)
        else
          {:error, error}
        end
    end
  end

  # Get retry delay based on attempt number
  # Attempt 1: 0ms (immediate first try)
  # Attempt 2: 100ms delay before retry
  # Attempt 3: 300ms delay before retry
  @spec get_retry_delay(pos_integer()) :: non_neg_integer()
  defp get_retry_delay(1), do: @initial_delay_ms
  defp get_retry_delay(attempt) when attempt > 1, do: Enum.at(@retry_delays, attempt - 2, 300)
end
