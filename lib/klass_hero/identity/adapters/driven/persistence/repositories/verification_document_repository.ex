defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository do
  @moduledoc """
  Ecto-based repository for verification documents.

  Implements the ForStoringVerificationDocuments port with:
  - Domain entity mapping via VerificationDocumentMapper
  - Idiomatic "let it crash" error handling

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringVerificationDocuments

  import Ecto.Query

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.VerificationDocumentMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.VerificationDocumentSchema
  alias KlassHero.Repo

  @impl true
  @doc """
  Creates a new verification document in the database.

  Returns:
  - `{:ok, VerificationDocument.t()}` on success
  - `{:error, changeset}` on validation failure
  """
  def create(document) do
    attrs = VerificationDocumentMapper.to_schema(document)

    %VerificationDocumentSchema{}
    |> VerificationDocumentSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        {:ok, VerificationDocumentMapper.to_domain(schema)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  @doc """
  Retrieves a verification document by its ID.

  Returns:
  - `{:ok, VerificationDocument.t()}` when document is found
  - `{:error, :not_found}` when no document exists with the given ID
  """
  def get(id) do
    case Repo.get(VerificationDocumentSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, VerificationDocumentMapper.to_domain(schema)}
    end
  end

  @impl true
  @doc """
  Retrieves all verification documents for a specific provider.

  Documents are ordered by inserted_at descending (most recent first).

  Returns:
  - `{:ok, [VerificationDocument.t()]}` - List of documents (may be empty)
  """
  def get_by_provider(provider_id) do
    docs =
      VerificationDocumentSchema
      |> where([d], d.provider_id == ^provider_id)
      |> order_by([d], desc: d.inserted_at)
      |> Repo.all()
      |> Enum.map(&VerificationDocumentMapper.to_domain/1)

    {:ok, docs}
  end

  @impl true
  @doc """
  Updates an existing verification document in the database.

  Returns:
  - `{:ok, VerificationDocument.t()}` on success
  - `{:error, :not_found}` when document doesn't exist
  - `{:error, changeset}` on validation failure
  """
  def update(document) do
    case Repo.get(VerificationDocumentSchema, document.id) do
      nil ->
        {:error, :not_found}

      schema ->
        attrs = VerificationDocumentMapper.to_schema(document)

        schema
        |> VerificationDocumentSchema.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated} -> {:ok, VerificationDocumentMapper.to_domain(updated)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  @doc """
  Lists all verification documents with pending status.

  Documents are ordered by inserted_at ascending (oldest first) to support
  FIFO processing of pending reviews.

  Returns:
  - `{:ok, [VerificationDocument.t()]}` - List of pending documents (may be empty)
  """
  def list_pending do
    docs =
      VerificationDocumentSchema
      |> where([d], d.status == "pending")
      |> order_by([d], asc: d.inserted_at)
      |> Repo.all()
      |> Enum.map(&VerificationDocumentMapper.to_domain/1)

    {:ok, docs}
  end

  @impl true
  @doc """
  Lists all verification documents with the specified status.

  Documents are ordered by inserted_at descending (most recent first).

  Returns:
  - `{:ok, [VerificationDocument.t()]}` - List of documents with matching status (may be empty)
  """
  def list_by_status(status) when is_atom(status) do
    status_string = Atom.to_string(status)

    docs =
      VerificationDocumentSchema
      |> where([d], d.status == ^status_string)
      |> order_by([d], desc: d.inserted_at)
      |> Repo.all()
      |> Enum.map(&VerificationDocumentMapper.to_domain/1)

    {:ok, docs}
  end
end
