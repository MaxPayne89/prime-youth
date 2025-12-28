defmodule PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepository do
  @moduledoc """
  Repository implementation for child persistence.

  Implements the ForStoringChildren port with:
  - Domain entity mapping via ChildMapper
  - Idiomatic "let it crash" error handling

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour PrimeYouth.Family.Domain.Ports.ForStoringChildren

  import Ecto.Query

  alias PrimeYouth.Family.Adapters.Driven.Persistence.Mappers.ChildMapper
  alias PrimeYouth.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias PrimeYouth.Repo
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  def get_by_id(child_id) when is_binary(child_id) do
    Logger.info(
      "[ChildRepository] Fetching child by ID",
      child_id: child_id
    )

    # Use dump/1 to validate UUID format - cast/1 incorrectly accepts 16-byte binaries
    case Ecto.UUID.dump(child_id) do
      {:ok, _binary} ->
        case Repo.get(ChildSchema, child_id) do
          nil ->
            Logger.info(
              "[ChildRepository] Child not found",
              child_id: child_id
            )

            {:error, :not_found}

          schema ->
            child = ChildMapper.to_domain(schema)

            Logger.info(
              "[ChildRepository] Successfully retrieved child",
              child_id: child.id,
              parent_id: child.parent_id
            )

            {:ok, child}
        end

      :error ->
        Logger.info(
          "[ChildRepository] Invalid UUID format",
          child_id: child_id
        )

        {:error, :not_found}
    end
  end

  @impl true
  def create(attrs) when is_map(attrs) do
    Logger.info(
      "[ChildRepository] Creating child",
      parent_id: attrs[:parent_id],
      first_name: attrs[:first_name],
      last_name: attrs[:last_name]
    )

    changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

    case Repo.insert(changeset) do
      {:ok, schema} ->
        child = ChildMapper.to_domain(schema)

        Logger.info(
          "[ChildRepository] Successfully created child",
          child_id: child.id,
          parent_id: child.parent_id,
          first_name: child.first_name,
          last_name: child.last_name
        )

        {:ok, child}

      {:error, changeset} ->
        Logger.warning(
          "[ChildRepository] Changeset validation failed during create",
          error_id: ErrorIds.child_validation_error(),
          errors: changeset.errors
        )

        {:error, changeset}
    end
  end

  @impl true
  def list_by_parent(parent_id) when is_binary(parent_id) do
    Logger.info(
      "[ChildRepository] Listing children by parent",
      parent_id: parent_id
    )

    children =
      ChildSchema
      |> where([c], c.parent_id == ^parent_id)
      |> order_by([c], asc: c.first_name, asc: c.last_name)
      |> Repo.all()
      |> ChildMapper.to_domain_list()

    Logger.info(
      "[ChildRepository] Successfully listed children",
      parent_id: parent_id,
      count: length(children)
    )

    children
  end
end
