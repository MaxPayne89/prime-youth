defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository do
  @moduledoc """
  Repository implementation for child persistence.

  Implements the ForStoringChildren port with:
  - Domain entity mapping via ChildMapper
  - Idiomatic "let it crash" error handling

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringChildren

  import Ecto.Query

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ChildMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias KlassHero.Repo
  alias KlassHeroWeb.ErrorIds

  require Logger

  @impl true
  def get_by_id(child_id) when is_binary(child_id) do
    Logger.info(
      "[Identity.ChildRepository] Fetching child by ID",
      child_id: child_id
    )

    case Ecto.UUID.dump(child_id) do
      {:ok, _binary} ->
        case Repo.get(ChildSchema, child_id) do
          nil ->
            Logger.info(
              "[Identity.ChildRepository] Child not found",
              child_id: child_id
            )

            {:error, :not_found}

          schema ->
            child = ChildMapper.to_domain(schema)

            Logger.info(
              "[Identity.ChildRepository] Successfully retrieved child",
              child_id: child.id,
              parent_id: child.parent_id
            )

            {:ok, child}
        end

      :error ->
        Logger.info(
          "[Identity.ChildRepository] Invalid UUID format",
          child_id: child_id
        )

        {:error, :not_found}
    end
  end

  @impl true
  def create(attrs) when is_map(attrs) do
    Logger.info(
      "[Identity.ChildRepository] Creating child",
      parent_id: attrs[:parent_id],
      first_name: attrs[:first_name],
      last_name: attrs[:last_name]
    )

    changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

    case Repo.insert(changeset) do
      {:ok, schema} ->
        child = ChildMapper.to_domain(schema)

        Logger.info(
          "[Identity.ChildRepository] Successfully created child",
          child_id: child.id,
          parent_id: child.parent_id,
          first_name: child.first_name,
          last_name: child.last_name
        )

        {:ok, child}

      {:error, changeset} ->
        Logger.warning(
          "[Identity.ChildRepository] Changeset validation failed during create",
          error_id: ErrorIds.child_validation_error(),
          errors: changeset.errors
        )

        {:error, changeset}
    end
  end

  @impl true
  def list_by_parent(parent_id) when is_binary(parent_id) do
    Logger.info(
      "[Identity.ChildRepository] Listing children by parent",
      parent_id: parent_id
    )

    children =
      ChildSchema
      |> where([c], c.parent_id == ^parent_id)
      |> order_by([c], asc: c.first_name, asc: c.last_name)
      |> Repo.all()
      |> ChildMapper.to_domain_list()

    Logger.info(
      "[Identity.ChildRepository] Successfully listed children",
      parent_id: parent_id,
      count: length(children)
    )

    children
  end
end
