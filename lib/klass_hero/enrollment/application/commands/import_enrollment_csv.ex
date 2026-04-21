defmodule KlassHero.Enrollment.Application.Commands.ImportEnrollmentCsv do
  @moduledoc """
  Use case for importing enrollment invites from a CSV file.

  Orchestrates: parse CSV -> validate rows -> detect duplicates -> persist batch.
  All-or-nothing: if any row fails, nothing is persisted.
  """

  alias KlassHero.Enrollment.Application.ChangesetErrors
  alias KlassHero.Enrollment.Application.ProviderProgramContext
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Enrollment.Domain.Models.BulkEnrollmentInvite
  alias KlassHero.Enrollment.Domain.Services.CsvParser
  alias KlassHero.Enrollment.Domain.Services.ImportRowValidator
  alias KlassHero.Shared.EventDispatchHelper

  @invite_reader Application.compile_env!(:klass_hero, [
                   :enrollment,
                   :for_querying_bulk_enrollment_invites
                 ])
  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])

  @spec execute(binary(), binary()) ::
          {:ok, %{created: non_neg_integer()}}
          | {:error, %{parse_errors: list()}}
          | {:error, %{validation_errors: list()}}
          | {:error, %{duplicate_errors: list()}}
  def execute(provider_id, csv_binary) when is_binary(provider_id) and is_binary(csv_binary) do
    with {:ok, rows} <- parse_csv(csv_binary),
         {:ok, context} <- build_context(provider_id),
         {:ok, validated_rows} <- validate_all_rows(rows, context),
         {:ok, validated_rows} <- check_batch_duplicates(validated_rows),
         {:ok, validated_rows} <- check_existing_duplicates(validated_rows),
         {:ok, count} <- persist_batch(validated_rows) do
      program_ids = validated_rows |> Enum.map(& &1.program_id) |> Enum.uniq()
      publish_event(provider_id, program_ids, count)
      {:ok, %{created: count}}
    end
  end

  defp parse_csv(csv_binary) do
    case CsvParser.parse(csv_binary) do
      {:ok, rows} ->
        {:ok, rows}

      {:error, :empty_csv} ->
        {:error, %{parse_errors: [{0, "CSV file is empty or has no data rows"}]}}

      {:error, {:invalid_headers, missing}} ->
        {:error, %{parse_errors: [{0, "Missing required columns: #{inspect(missing)}"}]}}

      {:error, row_errors} when is_list(row_errors) ->
        {:error, %{parse_errors: row_errors}}
    end
  end

  # LiveView renders parse_errors in the CSV uploader; wrap the shared
  # helper's generic errors into that shape so no new UI paths are needed.
  defp build_context(provider_id) do
    case ProviderProgramContext.for_provider(provider_id) do
      {:ok, context} ->
        {:ok, context}

      {:error, :no_programs} ->
        {:error,
         %{
           parse_errors: [
             {0, "No programs found for this provider. Create programs before importing."}
           ]
         }}

      {:error, {:title_collisions, titles}} ->
        msg =
          "Program titles must be unique ignoring case. Conflicting titles: " <>
            Enum.join(titles, ", ")

        {:error, %{parse_errors: [{0, msg}]}}
    end
  end

  defp validate_all_rows(rows, context) do
    {validated, errors} =
      rows
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {row, row_num}, {valid_acc, error_acc} ->
        case ImportRowValidator.validate(row, context) do
          {:ok, validated_row} -> {[validated_row | valid_acc], error_acc}
          {:error, field_errors} -> {valid_acc, [{row_num, field_errors} | error_acc]}
        end
      end)

    if errors == [] do
      {:ok, Enum.reverse(validated)}
    else
      {:error, %{validation_errors: Enum.reverse(errors)}}
    end
  end

  # Catching duplicates in-batch gives the user row-number errors; the DB
  # unique constraint would also reject them but with a less helpful shape.
  defp check_batch_duplicates(rows) do
    {_seen, duplicates} =
      rows
      |> Enum.with_index(1)
      |> Enum.reduce({MapSet.new(), []}, fn {row, row_num}, {seen, dupes} ->
        key = dedup_key(row)

        if MapSet.member?(seen, key) do
          {seen,
           [
             {row_num, "Duplicate entry in CSV: same program, guardian email, and child name"}
             | dupes
           ]}
        else
          {MapSet.put(seen, key), dupes}
        end
      end)

    if duplicates == [] do
      {:ok, rows}
    else
      {:error, %{duplicate_errors: Enum.reverse(duplicates)}}
    end
  end

  defp check_existing_duplicates(rows) do
    program_ids = rows |> Enum.map(& &1.program_id) |> Enum.uniq()
    existing_keys = @invite_reader.list_existing_keys_for_programs(program_ids)

    duplicates =
      rows
      |> Enum.with_index(1)
      |> Enum.reduce([], fn {row, row_num}, dupes ->
        if MapSet.member?(existing_keys, dedup_key(row)) do
          [{row_num, "Invite already exists for this child and program"} | dupes]
        else
          dupes
        end
      end)

    if duplicates == [] do
      {:ok, rows}
    else
      {:error, %{duplicate_errors: Enum.reverse(duplicates)}}
    end
  end

  defp persist_batch(validated_rows) do
    case @invite_repository.create_batch(validated_rows) do
      {:ok, count} ->
        {:ok, count}

      {:error, {index, %Ecto.Changeset{} = changeset}} ->
        {:error, %{validation_errors: [{index + 1, ChangesetErrors.field_list(changeset)}]}}
    end
  end

  defp publish_event(provider_id, program_ids, count) do
    EnrollmentEvents.bulk_invites_imported(provider_id, program_ids, count)
    |> EventDispatchHelper.dispatch(KlassHero.Enrollment)
  end

  defp dedup_key(row) do
    BulkEnrollmentInvite.dedup_key(
      row.program_id,
      row.guardian_email,
      row.child_first_name,
      row.child_last_name
    )
  end
end
