defmodule PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepository do
  @moduledoc """
  Repository implementation for storing and retrieving parent profiles from the database.

  Implements the ForStoringParents port with:
  - Domain entity mapping via ParentMapper
  - Idiomatic "let it crash" error handling

  Data integrity is enforced at the database level through:
  - NOT NULL constraint on identity_id
  - UNIQUE constraint on identity_id (prevents duplicate profiles)

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour PrimeYouth.Parenting.Domain.Ports.ForStoringParents

  import Ecto.Query

  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Mappers.ParentMapper
  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Schemas.ParentSchema
  alias PrimeYouth.Repo
  alias PrimeYouth.Shared.Adapters.Driven.Persistence.EctoErrorHelpers
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Creates a new parent profile in the database.

  Returns:
  - `{:ok, Parent.t()}` on success
  - `{:error, :duplicate_identity}` - Parent profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  def create_parent_profile(attrs) when is_map(attrs) do
    Logger.info("[ParentRepository] Creating parent profile",
      identity_id: attrs[:identity_id]
    )

    %ParentSchema{}
    |> ParentSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        parent = ParentMapper.to_domain(schema)

        Logger.info(
          "[ParentRepository] Successfully created parent profile (ID: #{parent.id}) for identity_id: #{parent.identity_id}"
        )

        {:ok, parent}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id) do
          Logger.warning(
            "[ParentRepository] Duplicate parent profile",
            error_id: ErrorIds.parent_duplicate_identity(),
            identity_id: attrs[:identity_id]
          )

          {:error, :duplicate_identity}
        else
          Logger.warning(
            "[ParentRepository] Validation error creating parent profile",
            identity_id: attrs[:identity_id],
            errors: inspect(changeset.errors)
          )

          {:error, changeset}
        end
    end
  end

  @impl true
  @doc """
  Retrieves a parent profile by identity ID from the database.

  Returns:
  - `{:ok, Parent.t()}` when parent profile is found
  - `{:error, :not_found}` when no parent profile exists with the given identity_id
  """
  def get_by_identity_id(identity_id) when is_binary(identity_id) do
    Logger.info("[ParentRepository] Retrieving parent profile by identity_id: #{identity_id}")

    case Repo.one(from p in ParentSchema, where: p.identity_id == ^identity_id) do
      nil ->
        Logger.info("[ParentRepository] Parent profile not found for identity_id: #{identity_id}")

        {:error, :not_found}

      schema ->
        parent = ParentMapper.to_domain(schema)

        Logger.info(
          "[ParentRepository] Successfully retrieved parent profile (ID: #{parent.id}) for identity_id: #{identity_id}"
        )

        {:ok, parent}
    end
  end

  @impl true
  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean directly.
  """
  def has_profile?(identity_id) when is_binary(identity_id) do
    Logger.info(
      "[ParentRepository] Checking if parent profile exists for identity_id: #{identity_id}"
    )

    exists =
      ParentSchema
      |> where([p], p.identity_id == ^identity_id)
      |> Repo.exists?()

    Logger.info(
      "[ParentRepository] Parent profile existence check for identity_id #{identity_id}: #{exists}"
    )

    exists
  end
end
