defmodule KlassHero.Provider.Application.UseCases.Verification.SubmitVerificationDocument do
  @moduledoc """
  Use case for provider submitting a verification document.

  Orchestrates the document submission workflow:
  1. Validates input parameters
  2. Uploads file to private storage bucket
  3. Creates verification document record with pending status

  The document starts in :pending status and awaits admin review.
  """

  alias KlassHero.Provider.Domain.Models.VerificationDocument
  alias KlassHero.Shared.Storage

  @required_string_fields [:provider_profile_id, :original_filename, :document_type]

  @repository Application.compile_env!(:klass_hero, [
                :provider,
                :for_storing_verification_documents
              ])

  @doc """
  Submits a verification document for a provider.

  ## Parameters

  - `provider_profile_id` - ID of the provider submitting the document
  - `document_type` - Type of document (business_registration, insurance_certificate, etc.)
  - `file_binary` - Binary content of the uploaded file
  - `original_filename` - Original name of the uploaded file
  - `content_type` - MIME type of the file (optional, defaults to application/octet-stream)
  - `storage_opts` - Additional options passed to the storage adapter (optional)

  ## Returns

  - `{:ok, VerificationDocument.t()}` on success
  - `{:error, keyword()}` with validation errors
  """
  def execute(params) do
    with :ok <- validate_params(params),
         {:ok, file_url} <- upload_file(params),
         {:ok, document} <- create_document(params, file_url) do
      persist_document(document)
    end
  end

  # Trigger: params map may be missing required fields
  # Why: early validation prevents partial operations (e.g., uploading file then failing)
  # Outcome: returns validation errors before any side effects occur
  defp validate_params(params) do
    errors =
      Enum.reduce(@required_string_fields, [], fn field, acc ->
        case params[field] do
          val when is_binary(val) and byte_size(val) > 0 -> acc
          _ -> [{field, "is required"} | acc]
        end
      end)

    errors =
      if is_nil(params[:file_binary]),
        do: [{:file_binary, "is required"} | errors],
        else: errors

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  # Trigger: params contain file binary and metadata
  # Why: files are stored in private bucket for security (verification docs are sensitive)
  # Outcome: file stored in object storage, returns storage path/key
  defp upload_file(params) do
    path = build_path(params[:provider_profile_id], params[:original_filename])

    opts =
      [content_type: params[:content_type] || "application/octet-stream"]
      |> Keyword.merge(Map.get(params, :storage_opts, []))

    Storage.upload(:private, path, params[:file_binary], opts)
  end

  # Trigger: filename may contain unsafe characters for URLs/storage
  # Why: sanitize to prevent path traversal or encoding issues
  # Outcome: safe filename with only alphanumeric, dots, underscores, and hyphens
  defp build_path(provider_id, filename) do
    safe_filename = String.replace(filename, ~r/[^a-zA-Z0-9._-]/, "_")
    timestamp = System.system_time(:millisecond)
    "verification-docs/providers/#{provider_id}/#{timestamp}_#{safe_filename}"
  end

  defp create_document(params, file_url) do
    VerificationDocument.new(%{
      id: Ecto.UUID.generate(),
      provider_profile_id: params[:provider_profile_id],
      document_type: params[:document_type],
      file_url: file_url,
      original_filename: params[:original_filename]
    })
  end

  defp persist_document(document) do
    @repository.create(document)
  end
end
