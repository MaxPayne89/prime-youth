defmodule KlassHero.Enrollment.Application.UseCases.ImportEnrollmentCsv do
  @moduledoc """
  Use case for importing enrollment invites from a CSV file.

  Orchestrates: parse CSV -> validate rows -> detect duplicates -> persist batch.
  All-or-nothing: if any row fails, nothing is persisted.
  """

  alias KlassHero.Enrollment.Domain.Services.CsvParser
  alias KlassHero.Enrollment.Domain.Services.ImportRowValidator

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])
  @program_catalog_acl Application.compile_env!(:klass_hero, [
                         :enrollment,
                         :for_resolving_program_catalog
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

  defp build_context(provider_id) do
    programs_by_title = @program_catalog_acl.list_program_titles_for_provider(provider_id)

    # Trigger: provider has no programs in the catalog
    # Why: every CSV row requires a valid program reference; importing with
    #      zero programs would fail on every row with a confusing per-row error
    # Outcome: single clear error telling the provider to create programs first
    if programs_by_title == %{} do
      {:error,
       %{
         parse_errors: [
           {0, "No programs found for this provider. Create programs before importing."}
         ]
       }}
    else
      {:ok, %{provider_id: provider_id, programs_by_title: programs_by_title}}
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

  # Trigger: two rows in the same CSV have the same program + email + child name
  # Why: the DB unique constraint would reject the batch anyway, but catching
  #      it here gives a better error message with row numbers
  # Outcome: duplicate rows flagged before hitting the database
  defp check_batch_duplicates(rows) do
    {_seen, duplicates} =
      rows
      |> Enum.with_index(1)
      |> Enum.reduce({MapSet.new(), []}, fn {row, row_num}, {seen, dupes} ->
        key = duplicate_key(row)

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

  # Trigger: rows match invites already in the database
  # Why: re-importing the same children would violate the unique constraint
  # Outcome: already-imported rows flagged with a clear message
  defp check_existing_duplicates(rows) do
    program_ids = rows |> Enum.map(& &1.program_id) |> Enum.uniq()
    existing_keys = @invite_repository.list_existing_keys_for_programs(program_ids)

    duplicates =
      rows
      |> Enum.with_index(1)
      |> Enum.reduce([], fn {row, row_num}, dupes ->
        key = duplicate_key(row)

        if MapSet.member?(existing_keys, key) do
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

  # Trigger: create_batch returns {index, changeset} on failure
  # Why: callers expect structured error maps, not raw changesets
  # Outcome: changeset errors formatted into the standard error report shape
  defp persist_batch(validated_rows) do
    case @invite_repository.create_batch(validated_rows) do
      {:ok, count} ->
        {:ok, count}

      {:error, {index, %Ecto.Changeset{} = changeset}} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        formatted =
          Enum.map(errors, fn {field, messages} ->
            {field, Enum.join(messages, ", ")}
          end)

        {:error, %{validation_errors: [{index + 1, formatted}]}}
    end
  end

  defp duplicate_key(row) do
    {
      row.program_id,
      String.downcase(row.guardian_email),
      String.downcase(row.child_first_name),
      String.downcase(row.child_last_name)
    }
  end
end
