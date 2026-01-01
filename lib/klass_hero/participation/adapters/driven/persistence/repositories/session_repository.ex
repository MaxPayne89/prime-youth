defmodule KlassHero.Participation.Adapters.Driven.Persistence.Repositories.SessionRepository do
  @moduledoc """
  Ecto-based implementation of the session repository.

  Implements the ForManagingSessions port using PostgreSQL via Ecto.
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForManagingSessions

  import Ecto.Query

  alias KlassHero.Participation.Adapters.Driven.Persistence.Mappers.ProgramSessionMapper
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias KlassHero.Participation.Domain.Models.ProgramSession
  alias KlassHero.Repo
  alias KlassHeroWeb.ErrorIds

  @impl true
  def create(%ProgramSession{} = session) do
    attrs = ProgramSessionMapper.to_persistence(session)

    attrs
    |> ProgramSessionSchema.create_changeset()
    |> Repo.insert()
    |> handle_insert_result()
  end

  @impl true
  def get_by_id(id) when is_binary(id) do
    case Repo.get(ProgramSessionSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, ProgramSessionMapper.to_domain(schema)}
    end
  end

  @impl true
  def list_by_program(program_id) when is_binary(program_id) do
    from(s in ProgramSessionSchema,
      where: s.program_id == ^program_id,
      order_by: [asc: s.session_date, asc: s.start_time]
    )
    |> Repo.all()
    |> Enum.map(&ProgramSessionMapper.to_domain/1)
  end

  @impl true
  def list_today_sessions(date) do
    from(s in ProgramSessionSchema,
      where: s.session_date == ^date,
      order_by: [asc: s.start_time]
    )
    |> Repo.all()
    |> Enum.map(&ProgramSessionMapper.to_domain/1)
  end

  @impl true
  def update(%ProgramSession{} = session) do
    case Repo.get(ProgramSessionSchema, session.id) do
      nil ->
        {:error, :not_found}

      schema ->
        attrs = ProgramSessionMapper.update_schema(schema, session)

        schema
        |> ProgramSessionSchema.update_changeset(attrs)
        |> Repo.update()
        |> handle_update_result()
    end
  end

  @impl true
  def list_by_provider_and_date(provider_id, date) when is_binary(provider_id) do
    # Note: Full provider filtering requires provider-program relationship in schema.
    # Currently returns all sessions for date as a simplified implementation.
    # TODO: Add provider_id to sessions or join through programs table.
    _ = provider_id

    from(s in ProgramSessionSchema,
      where: s.session_date == ^date,
      order_by: [asc: s.start_time]
    )
    |> Repo.all()
    |> Enum.map(&ProgramSessionMapper.to_domain/1)
  end

  @impl true
  def get_many_by_ids(ids) when is_list(ids) do
    from(s in ProgramSessionSchema,
      where: s.id in ^ids
    )
    |> Repo.all()
    |> Enum.map(&ProgramSessionMapper.to_domain/1)
  end

  defp handle_insert_result({:ok, schema}) do
    {:ok, ProgramSessionMapper.to_domain(schema)}
  end

  defp handle_insert_result({:error, %Ecto.Changeset{errors: errors} = changeset}) do
    if has_unique_constraint_error?(errors) do
      {:error, :duplicate_session}
    else
      {:error, ErrorIds.session_create_failed(changeset)}
    end
  end

  defp handle_update_result({:ok, schema}) do
    {:ok, ProgramSessionMapper.to_domain(schema)}
  end

  defp handle_update_result({:error, %Ecto.Changeset{} = changeset}) do
    if changeset.errors[:lock_version] do
      {:error, :stale_data}
    else
      {:error, ErrorIds.session_update_failed(changeset)}
    end
  end

  defp has_unique_constraint_error?(errors) do
    Enum.any?(errors, fn {_field, {_msg, opts}} ->
      opts[:constraint] == :unique
    end)
  end
end
