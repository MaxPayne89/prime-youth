defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.StaffMemberRepository do
  @moduledoc """
  Repository implementation for storing and retrieving staff members.

  Implements the ForStoringStaffMembers port.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringStaffMembers

  import Ecto.Query

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.StaffMemberMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Repo

  require Logger

  @impl true
  def create(attrs) when is_map(attrs) do
    %StaffMemberSchema{}
    |> StaffMemberSchema.create_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        {:ok, StaffMemberMapper.to_domain(schema)}

      {:error, changeset} ->
        Logger.warning(
          "[Identity.StaffMemberRepository] Validation error creating staff member",
          provider_id: attrs[:provider_id],
          errors: inspect(changeset.errors)
        )

        {:error, changeset}
    end
  end

  @impl true
  def get(id) when is_binary(id) do
    case Repo.get(StaffMemberSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, StaffMemberMapper.to_domain(schema)}
    end
  end

  @impl true
  def list_by_provider(provider_id) when is_binary(provider_id) do
    members =
      StaffMemberSchema
      |> where([s], s.provider_id == ^provider_id)
      |> order_by([s], asc: s.inserted_at)
      |> Repo.all()
      |> StaffMemberMapper.to_domain_list()

    {:ok, members}
  end

  @impl true
  def list_active_by_provider(provider_id) when is_binary(provider_id) do
    members =
      StaffMemberSchema
      |> where([s], s.provider_id == ^provider_id and s.active == true)
      |> order_by([s], asc: s.inserted_at)
      |> Repo.all()
      |> StaffMemberMapper.to_domain_list()

    {:ok, members}
  end

  @impl true
  def update(staff_member) do
    case Repo.get(StaffMemberSchema, staff_member.id) do
      nil ->
        {:error, :not_found}

      schema ->
        attrs = StaffMemberMapper.to_schema(staff_member)

        with {:ok, updated} <-
               schema
               |> StaffMemberSchema.edit_changeset(attrs)
               |> Repo.update() do
          {:ok, StaffMemberMapper.to_domain(updated)}
        end
    end
  end

  @impl true
  def delete(id) when is_binary(id) do
    case Repo.get(StaffMemberSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        {:ok, _} = Repo.delete(schema)
        :ok
    end
  end
end
