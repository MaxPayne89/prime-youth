defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ConsentRepository do
  @moduledoc """
  Repository implementation for consent persistence.

  Implements the ForStoringConsents port with:
  - Domain entity mapping via ConsentMapper
  - Idiomatic "let it crash" error handling

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringConsents

  import Ecto.Query

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ConsentMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ConsentSchema
  alias KlassHero.Repo

  require Logger

  @impl true
  def grant(attrs) when is_map(attrs) do
    changeset = ConsentSchema.changeset(%ConsentSchema{}, attrs)

    case Repo.insert(changeset) do
      {:ok, schema} ->
        {:ok, ConsentMapper.to_domain(schema)}

      {:error, changeset} ->
        Logger.warning(
          "[Identity.ConsentRepository] Changeset validation failed during grant",
          errors: changeset.errors
        )

        {:error, changeset}
    end
  end

  @impl true
  def withdraw(consent_id, %DateTime{} = withdrawn_at) when is_binary(consent_id) do
    case get_schema(consent_id) do
      {:ok, schema} ->
        changeset = ConsentSchema.withdraw_changeset(schema, withdrawn_at)

        case Repo.update(changeset) do
          {:ok, updated} ->
            {:ok, ConsentMapper.to_domain(updated)}

          {:error, changeset} ->
            Logger.warning(
              "[Identity.ConsentRepository] Consent withdrawal update failed",
              consent_id: consent_id,
              errors: changeset.errors
            )

            {:error, changeset}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @impl true
  def get_active_for_child(child_id, consent_type)
      when is_binary(child_id) and is_binary(consent_type) do
    query =
      ConsentSchema
      |> where([c], c.child_id == ^child_id)
      |> where([c], c.consent_type == ^consent_type)
      |> where([c], is_nil(c.withdrawn_at))
      |> limit(1)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, ConsentMapper.to_domain(schema)}
    end
  end

  @impl true
  def list_active_by_child(child_id) when is_binary(child_id) do
    ConsentSchema
    |> where([c], c.child_id == ^child_id)
    |> where([c], is_nil(c.withdrawn_at))
    |> order_by([c], asc: c.consent_type)
    |> Repo.all()
    |> ConsentMapper.to_domain_list()
  end

  @impl true
  def list_all_by_child(child_id) when is_binary(child_id) do
    ConsentSchema
    |> where([c], c.child_id == ^child_id)
    |> order_by([c], asc: c.consent_type, desc: c.granted_at)
    |> Repo.all()
    |> ConsentMapper.to_domain_list()
  end

  @impl true
  def delete_all_for_child(child_id) when is_binary(child_id) do
    {count, _} =
      ConsentSchema
      |> where([c], c.child_id == ^child_id)
      |> Repo.delete_all()

    {:ok, count}
  end

  defp get_schema(consent_id) do
    case Ecto.UUID.dump(consent_id) do
      {:ok, _binary} ->
        case Repo.get(ConsentSchema, consent_id) do
          nil -> {:error, :not_found}
          schema -> {:ok, schema}
        end

      :error ->
        {:error, :not_found}
    end
  end
end
