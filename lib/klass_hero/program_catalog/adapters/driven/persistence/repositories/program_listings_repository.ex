defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepository do
  @moduledoc """
  Read-side repository for the program_listings denormalized table.

  Implements the ForListingProgramSummaries port. This repository only reads —
  the projection GenServer handles all writes to the program_listings table.

  Returns lightweight ProgramListing DTOs (no domain entities, no value objects).
  Uses cursor-based pagination matching the write-side ProgramRepository pattern.
  """

  @behaviour KlassHero.ProgramCatalog.Domain.Ports.ForListingProgramSummaries

  use KlassHero.Shared.Tracing

  import Ecto.Query

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Types.Pagination.PageResult

  require Logger

  @impl true
  def list_paginated(limit, cursor, category) do
    span do
      set_attributes("db", operation: "select", entity: "program_listing")

      Logger.debug("[ProgramListingsRepository] Listing paginated program listings",
        limit: limit,
        has_cursor: !is_nil(cursor),
        category: category
      )

      with {:ok, cursor_data} <- decode_cursor(cursor) do
        schemas = fetch_page(limit, cursor_data, category)

        # Trigger: fetched one extra record beyond the limit
        # Why: determines if more pages exist without a separate COUNT query
        # Outcome: sets has_more flag and trims result to requested limit
        {items, has_more} =
          if length(schemas) > limit do
            {Enum.take(schemas, limit), true}
          else
            {schemas, false}
          end

        next_cursor =
          if has_more do
            items |> List.last() |> encode_cursor()
          end

        dtos = Enum.map(items, &to_dto/1)
        page_result = PageResult.new(dtos, next_cursor, has_more)

        Logger.debug("[ProgramListingsRepository] Retrieved paginated listings",
          returned_count: length(dtos),
          has_more: has_more
        )

        {:ok, page_result}
      end
    end
  end

  @impl true
  def list_all do
    span do
      set_attributes("db", operation: "select", entity: "program_listing")

      Logger.debug("[ProgramListingsRepository] Listing all program listings")

      schemas =
        ProgramListingSchema
        |> order_by(asc: :title)
        |> Repo.all()

      dtos = Enum.map(schemas, &to_dto/1)

      Logger.debug("[ProgramListingsRepository] Retrieved all listings",
        count: length(dtos)
      )

      dtos
    end
  end

  @impl true
  def list_for_provider(provider_id) when is_binary(provider_id) do
    span do
      set_attributes("db", operation: "select", entity: "program_listing")

      Logger.debug("[ProgramListingsRepository] Listing programs for provider",
        provider_id: provider_id
      )

      schemas =
        ProgramListingSchema
        |> where([l], l.provider_id == ^provider_id)
        |> order_by([l], asc: l.title)
        |> Repo.all()

      dtos = Enum.map(schemas, &to_dto/1)

      Logger.debug("[ProgramListingsRepository] Retrieved provider listings",
        provider_id: provider_id,
        count: length(dtos)
      )

      dtos
    end
  end

  @impl true
  def get_by_id(id) when is_binary(id) do
    span do
      set_attributes("db", operation: "select", entity: "program_listing")

      # Use dump/1 to validate UUID format — cast/1 incorrectly accepts 16-byte binaries
      case Ecto.UUID.dump(id) do
        {:ok, _binary} ->
          case Repo.get(ProgramListingSchema, id) do
            nil ->
              Logger.debug("[ProgramListingsRepository] Listing not found", entity_id: id)
              {:error, :not_found}

            schema ->
              {:ok, to_dto(schema)}
          end

        :error ->
          Logger.debug("[ProgramListingsRepository] Invalid UUID format", entity_id: id)
          {:error, :not_found}
      end
    end
  end

  # --- Private helpers ---

  defp fetch_page(limit, cursor_data, category) do
    ProgramListingSchema
    |> apply_category_filter(category)
    |> apply_end_date_filter()
    |> apply_cursor_filter(cursor_data)
    |> order_by([l], desc: l.inserted_at, desc: l.id)
    |> limit(^(limit + 1))
    |> Repo.all()
  end

  defp apply_category_filter(query, nil), do: query
  defp apply_category_filter(query, "all"), do: query

  defp apply_category_filter(query, category) when is_binary(category) do
    where(query, [l], l.category == ^category)
  end

  # Trigger: every public listing query
  # Why: programs that have already ended should not appear in /programs (issue #610);
  #      programs without an end_date are open-ended and continue to appear
  # Outcome: excludes rows where end_date < today, keeps end_date >= today and nil end_date
  defp apply_end_date_filter(query) do
    today = Date.utc_today()
    where(query, [l], is_nil(l.end_date) or l.end_date >= ^today)
  end

  defp apply_cursor_filter(query, nil), do: query

  defp apply_cursor_filter(query, {cursor_ts, cursor_id}) do
    # Trigger: cursor present from a previous page request
    # Why: seek pagination — skip all rows at or before the cursor position
    # Outcome: returns only rows after the cursor in (inserted_at DESC, id DESC) order
    where(
      query,
      [l],
      l.inserted_at < ^cursor_ts or
        (l.inserted_at == ^cursor_ts and l.id < ^cursor_id)
    )
  end

  defp to_dto(%ProgramListingSchema{} = schema) do
    ProgramListing.new(%{
      id: schema.id,
      title: schema.title,
      description: schema.description,
      category: schema.category,
      age_range: schema.age_range,
      price: schema.price,
      pricing_period: schema.pricing_period,
      location: schema.location,
      cover_image_url: schema.cover_image_url,
      instructor_name: schema.instructor_name,
      instructor_headshot_url: schema.instructor_headshot_url,
      start_date: schema.start_date,
      end_date: schema.end_date,
      meeting_days: schema.meeting_days,
      meeting_start_time: schema.meeting_start_time,
      meeting_end_time: schema.meeting_end_time,
      season: schema.season,
      registration_start_date: schema.registration_start_date,
      registration_end_date: schema.registration_end_date,
      provider_id: schema.provider_id,
      provider_verified: schema.provider_verified,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end

  # --- Cursor encoding/decoding ---
  # Matches the write-side ProgramRepository cursor format:
  # Base64 URL-encoded JSON: {"ts": unix_microseconds, "id": uuid_string}

  defp encode_cursor(%ProgramListingSchema{} = schema) do
    %{"ts" => DateTime.to_unix(schema.inserted_at, :microsecond), "id" => schema.id}
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp decode_cursor(nil), do: {:ok, nil}

  defp decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         {:ok, data} <- Jason.decode(decoded),
         {:ok, datetime} <- parse_cursor_timestamp(data["ts"]),
         {:ok, uuid} <- parse_cursor_uuid(data["id"]) do
      {:ok, {datetime, uuid}}
    else
      _ -> {:error, :invalid_cursor}
    end
  end

  defp parse_cursor_timestamp(ts) when is_integer(ts) do
    case DateTime.from_unix(ts, :microsecond) do
      {:ok, datetime} -> {:ok, datetime}
      {:error, _} -> {:error, :invalid_timestamp}
    end
  end

  defp parse_cursor_timestamp(_), do: {:error, :invalid_timestamp}

  defp parse_cursor_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_uuid}
    end
  end

  defp parse_cursor_uuid(_), do: {:error, :invalid_uuid}
end
