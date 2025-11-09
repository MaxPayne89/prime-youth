defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepository do
  @moduledoc """
  Ecto adapter implementing the ProgramRepository port.

  This is the infrastructure implementation of the repository using Ecto and PostgreSQL.
  Provides persistence operations for Program entities with full-text search capabilities.

  ## Features

  - List programs with filtering (category, age, location, price, status)
  - Full-text search with fuzzy matching using PostgreSQL
  - Preloading associations (schedules, locations, provider)
  - Approval workflow state transitions
  - Soft delete (archiving) support

  ## Configuration

  Configure this as the default repository implementation in `config.exs`:

  ```elixir
  config :prime_youth, :program_repository,
    PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepository
  ```
  """

  @behaviour PrimeYouth.ProgramCatalog.Domain.Ports.ProgramRepository

  import Ecto.Query, warn: false

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program
  alias PrimeYouth.ProgramCatalog.Domain.Entities, as: DomainEntities
  alias PrimeYouth.Repo

  require Logger

  @impl true
  def get(id) do
    case Repo.get(Program, id) |> preload_associations() do
      nil ->
        {:error, :not_found}

      program ->
        {:ok, to_domain_entity(program)}
    end
  end

  @impl true
  def list(filters \\ %{}) do
    Program
    |> apply_filters(filters)
    |> preload_query()
    |> Repo.all()
    |> Enum.map(&to_domain_entity/1)
  end

  @impl true
  def search(query, filters \\ %{}) when is_binary(query) do
    Program
    |> apply_search(query)
    |> apply_filters(filters)
    |> preload_query()
    |> Repo.all()
    |> Enum.map(&to_domain_entity/1)
  end

  @impl true
  def create(attrs) do
    %Program{}
    |> Program.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, program} ->
        program = preload_associations(program)
        {:ok, to_domain_entity(program)}

      error ->
        error
    end
  end

  @impl true
  def update(%DomainEntities.Program{id: id}, attrs) when is_binary(id) do
    case Repo.get(Program, id) do
      nil ->
        {:error, :not_found}

      program ->
        program
        |> Program.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_program} ->
            updated_program = preload_associations(updated_program)
            {:ok, to_domain_entity(updated_program)}

          error ->
            error
        end
    end
  end

  @impl true
  def delete(%DomainEntities.Program{id: id}) when is_binary(id) do
    case Repo.get(Program, id) do
      nil ->
        {:error, :not_found}

      program ->
        program
        |> Ecto.Changeset.change(archived_at: DateTime.utc_now())
        |> Repo.update()
        |> case do
          {:ok, archived_program} ->
            archived_program = preload_associations(archived_program)
            {:ok, to_domain_entity(archived_program)}

          error ->
            error
        end
    end
  end

  @impl true
  def list_by_provider(provider_id) when is_binary(provider_id) do
    Program
    |> where([p], p.provider_id == ^provider_id)
    |> where([p], is_nil(p.archived_at))
    |> order_by([p], desc: p.inserted_at)
    |> preload_query()
    |> Repo.all()
    |> Enum.map(&to_domain_entity/1)
  end

  @impl true
  def list_pending_approval do
    Program
    |> where([p], p.status == "pending_approval")
    |> where([p], is_nil(p.archived_at))
    |> order_by([p], asc: p.inserted_at)
    |> preload_query()
    |> Repo.all()
    |> Enum.map(&to_domain_entity/1)
  end

  @impl true
  def approve(program_id, admin_id) when is_binary(program_id) and is_binary(admin_id) do
    case Repo.get(Program, program_id) do
      nil ->
        {:error, :not_found}

      %Program{status: "pending_approval"} = program ->
        Logger.info(
          "Approving program: id=#{program_id}, admin=#{admin_id}, provider=#{program.provider_id}"
        )

        program
        |> Ecto.Changeset.change(status: "approved")
        |> Repo.update()
        |> case do
          {:ok, approved_program} ->
            approved_program = preload_associations(approved_program)

            # Broadcast approval notification via PubSub
            broadcast_approval_notification(approved_program, admin_id)

            {:ok, to_domain_entity(approved_program)}

          error ->
            error
        end

      _program ->
        {:error, :invalid_state_transition}
    end
  end

  @impl true
  def reject(program_id, admin_id, reason)
      when is_binary(program_id) and is_binary(admin_id) and is_binary(reason) do
    case Repo.get(Program, program_id) do
      nil ->
        {:error, :not_found}

      %Program{status: "pending_approval"} = program ->
        Logger.info(
          "Rejecting program: id=#{program_id}, admin=#{admin_id}, provider=#{program.provider_id}, reason=#{reason}"
        )

        program
        |> Ecto.Changeset.change(status: "rejected")
        |> Repo.update()
        |> case do
          {:ok, rejected_program} ->
            rejected_program = preload_associations(rejected_program)

            # Broadcast rejection notification via PubSub
            broadcast_rejection_notification(rejected_program, admin_id, reason)

            {:ok, to_domain_entity(rejected_program)}

          error ->
            error
        end

      _program ->
        {:error, :invalid_state_transition}
    end
  end

  # Private helper functions

  defp apply_filters(query, filters) do
    filters
    |> Enum.reduce(query, fn {key, value}, acc ->
      apply_filter(acc, key, value)
    end)
  end

  defp apply_filter(query, :category, category) when is_binary(category) do
    where(query, [p], p.category == ^category)
  end

  defp apply_filter(query, :age_min, age_min) when is_integer(age_min) do
    where(query, [p], p.age_max >= ^age_min)
  end

  defp apply_filter(query, :age_max, age_max) when is_integer(age_max) do
    where(query, [p], p.age_min <= ^age_max)
  end

  defp apply_filter(query, :city, city) when is_binary(city) do
    query
    |> join(:inner, [p], l in assoc(p, :locations), as: :location)
    |> where([location: l], ilike(l.city, ^"%#{city}%"))
    |> distinct([p], p.id)
  end

  defp apply_filter(query, :state, state) when is_binary(state) do
    query
    |> join(:inner, [p], l in assoc(p, :locations), as: :location)
    |> where([location: l], ilike(l.state, ^"%#{state}%"))
    |> distinct([p], p.id)
  end

  defp apply_filter(query, :price_min, price_min) when is_number(price_min) do
    price_decimal = Decimal.new(to_string(price_min))
    where(query, [p], p.price_amount >= ^price_decimal)
  end

  defp apply_filter(query, :price_max, price_max) when is_number(price_max) do
    price_decimal = Decimal.new(to_string(price_max))
    where(query, [p], p.price_amount <= ^price_decimal)
  end

  defp apply_filter(query, :is_prime_youth, is_prime_youth) when is_boolean(is_prime_youth) do
    where(query, [p], p.is_prime_youth == ^is_prime_youth)
  end

  defp apply_filter(query, :status, status) when is_binary(status) do
    where(query, [p], p.status == ^status)
  end

  defp apply_filter(query, :featured, true) do
    where(query, [p], p.featured == true)
  end

  defp apply_filter(query, :provider_id, provider_id) when is_binary(provider_id) do
    where(query, [p], p.provider_id == ^provider_id)
  end

  defp apply_filter(query, _key, _value), do: query

  defp apply_search(query, search_query) do
    search_term = "%#{search_query}%"

    query
    |> where(
      [p],
      ilike(p.title, ^search_term) or
        ilike(p.description, ^search_term) or
        fragment(
          "to_tsvector('english', ? || ' ' || ?) @@ plainto_tsquery('english', ?)",
          p.title,
          p.description,
          ^search_query
        )
    )
    |> order_by([p], desc: fragment("similarity(?, ?)", p.title, ^search_query))
  end

  defp preload_query(query) do
    query
    |> preload([:schedules, :locations, :provider])
    |> where([p], is_nil(p.archived_at))
  end

  defp preload_associations(nil), do: nil

  defp preload_associations(program) do
    Repo.preload(program, [:schedules, :locations, :provider])
  end

  defp to_domain_entity(%Program{} = program) do
    # Convert Ecto schema to domain entity
    # This is a simplified conversion - full conversion would map all fields
    # and reconstruct value objects (AgeRange, Pricing, etc.)
    program
  end

  defp broadcast_approval_notification(program, admin_id) do
    Phoenix.PubSub.broadcast(
      PrimeYouth.PubSub,
      "provider:#{program.provider_id}:notifications",
      {:program_approved, %{program_id: program.id, admin_id: admin_id}}
    )
  end

  defp broadcast_rejection_notification(program, admin_id, reason) do
    Phoenix.PubSub.broadcast(
      PrimeYouth.PubSub,
      "provider:#{program.provider_id}:notifications",
      {:program_rejected, %{program_id: program.id, admin_id: admin_id, reason: reason}}
    )
  end
end
