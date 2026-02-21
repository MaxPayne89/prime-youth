defmodule KlassHero.Family.Adapters.Driven.Persistence.Repositories.ChildRepository do
  @moduledoc """
  Repository implementation for child persistence.

  Implements the ForStoringChildren port with:
  - Domain entity mapping via ChildMapper
  - Idiomatic "let it crash" error handling

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Family.Domain.Ports.ForStoringChildren

  import Ecto.Query

  alias KlassHero.Family.Adapters.Driven.Persistence.Mappers.ChildMapper
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildGuardianSchema
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.ErrorIds

  require Logger

  @impl true
  def get_by_id(child_id) when is_binary(child_id) do
    case get_schema(child_id) do
      {:ok, schema} -> {:ok, ChildMapper.to_domain(schema)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @impl true
  def create(attrs) when is_map(attrs) do
    changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

    case Repo.insert(changeset) do
      {:ok, schema} ->
        {:ok, ChildMapper.to_domain(schema)}

      {:error, changeset} ->
        Logger.warning(
          "[Family.ChildRepository] Changeset validation failed during create",
          error_id: ErrorIds.child_validation_error(),
          errors: changeset.errors
        )

        {:error, changeset}
    end
  end

  @impl true
  def update(child_id, attrs) when is_binary(child_id) and is_map(attrs) do
    case get_schema(child_id) do
      {:ok, schema} ->
        changeset = ChildSchema.changeset(schema, attrs)

        case Repo.update(changeset) do
          {:ok, updated} ->
            {:ok, ChildMapper.to_domain(updated)}

          {:error, changeset} ->
            Logger.warning(
              "[Family.ChildRepository] Changeset validation failed during update",
              error_id: ErrorIds.child_validation_error(),
              errors: changeset.errors
            )

            {:error, changeset}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @impl true
  def delete(child_id) when is_binary(child_id) do
    case get_schema(child_id) do
      {:ok, schema} ->
        case Repo.delete(schema) do
          {:ok, _deleted} ->
            :ok

          {:error, changeset} ->
            Logger.warning(
              "[Family.ChildRepository] Delete failed",
              error_id: ErrorIds.child_validation_error(),
              child_id: child_id,
              errors: changeset.errors
            )

            {:error, changeset}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @impl true
  def anonymize(child_id, anonymized_attrs)
      when is_binary(child_id) and is_map(anonymized_attrs) do
    with {:ok, schema} <- get_schema(child_id),
         {:ok, updated} <-
           schema
           |> ChildSchema.anonymize_changeset(anonymized_attrs)
           |> Repo.update() do
      {:ok, ChildMapper.to_domain(updated)}
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning(
          "[Family.ChildRepository] Changeset validation failed during anonymize",
          error_id: ErrorIds.child_validation_error(),
          child_id: child_id,
          errors: changeset.errors
        )

        {:error, changeset}
    end
  end

  @impl true
  def list_by_ids(child_ids) when is_list(child_ids) do
    ChildSchema
    |> where([c], c.id in ^child_ids)
    |> Repo.all()
    |> ChildMapper.to_domain_list()
  end

  @impl true
  def create_with_guardian(attrs, guardian_id)
      when is_map(attrs) and is_binary(guardian_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:child, ChildSchema.changeset(%ChildSchema{}, attrs))
    |> Ecto.Multi.insert(:guardian_link, fn %{child: child} ->
      ChildGuardianSchema.changeset(%ChildGuardianSchema{}, %{
        child_id: child.id,
        guardian_id: guardian_id,
        relationship: "parent",
        is_primary: true
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{child: schema}} ->
        {:ok, ChildMapper.to_domain(schema)}

      {:error, :child, changeset, _changes} ->
        Logger.warning(
          "[Family.ChildRepository] Changeset validation failed during create_with_guardian",
          error_id: ErrorIds.child_validation_error(),
          errors: changeset.errors
        )

        {:error, changeset}

      {:error, :guardian_link, changeset, _changes} ->
        Logger.warning(
          "[Family.ChildRepository] Guardian link creation failed",
          error_id: ErrorIds.child_validation_error(),
          errors: changeset.errors
        )

        {:error, changeset}
    end
  end

  @impl true
  def child_belongs_to_guardian?(child_id, guardian_id)
      when is_binary(child_id) and is_binary(guardian_id) do
    ChildGuardianSchema
    |> where([cg], cg.child_id == ^child_id and cg.guardian_id == ^guardian_id)
    |> Repo.exists?()
  end

  @impl true
  def list_by_guardian(guardian_id) when is_binary(guardian_id) do
    ChildSchema
    |> join(:inner, [c], cg in ChildGuardianSchema, on: c.id == cg.child_id)
    |> where([_c, cg], cg.guardian_id == ^guardian_id)
    |> order_by([c], asc: c.first_name, asc: c.last_name)
    |> Repo.all()
    |> ChildMapper.to_domain_list()
  end

  defp get_schema(child_id) do
    case Ecto.UUID.dump(child_id) do
      {:ok, _binary} ->
        case Repo.get(ChildSchema, child_id) do
          nil -> {:error, :not_found}
          schema -> {:ok, schema}
        end

      :error ->
        {:error, :not_found}
    end
  end
end
