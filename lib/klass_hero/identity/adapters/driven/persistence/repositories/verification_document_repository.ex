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
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
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

    with {:ok, schema} <-
           %VerificationDocumentSchema{}
           |> VerificationDocumentSchema.changeset(attrs)
           |> Repo.insert() do
      {:ok, VerificationDocumentMapper.to_domain(schema)}
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
      |> VerificationDocumentMapper.to_domain_list()

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

        with {:ok, updated} <-
               schema
               |> VerificationDocumentSchema.changeset(attrs)
               |> Repo.update() do
          {:ok, VerificationDocumentMapper.to_domain(updated)}
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
      |> VerificationDocumentMapper.to_domain_list()

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
      |> VerificationDocumentMapper.to_domain_list()

    {:ok, docs}
  end

  @impl true
  @doc """
  Lists verification documents joined with provider business names for admin review.

  When status is nil, returns all documents ordered by inserted_at descending.
  When status is :pending, orders oldest-first (FIFO processing).
  Other statuses order newest-first.
  """
  def list_for_admin_review(status) do
    query =
      from d in VerificationDocumentSchema,
        join: p in ProviderProfileSchema,
        on: d.provider_id == p.id,
        select: {d, p.business_name}

    query =
      case status do
        nil ->
          order_by(query, [d], desc: d.inserted_at)

        :pending ->
          query
          |> where([d], d.status == "pending")
          |> order_by([d], asc: d.inserted_at)

        status when is_atom(status) ->
          status_string = Atom.to_string(status)

          query
          |> where([d], d.status == ^status_string)
          |> order_by([d], desc: d.inserted_at)
      end

    results =
      query
      |> Repo.all()
      |> Enum.map(fn {schema, business_name} ->
        %{
          document: VerificationDocumentMapper.to_domain(schema),
          provider_business_name: business_name
        }
      end)

    {:ok, results}
  end
end
