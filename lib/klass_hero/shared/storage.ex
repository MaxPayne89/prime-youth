defmodule KlassHero.Shared.Storage do
  @moduledoc """
  Public API for file storage operations.

  Delegates to the configured storage adapter (S3 in prod, Stub in tests).

  ## Bucket Types

  - `:public` - files accessible via direct URL (logos, program images)
  - `:private` - files require signed URLs with expiration (verification docs)

  ## Usage

      # Upload a logo
      {:ok, url} = Storage.upload(:public, "logos/providers/123/logo.png", binary)

      # Upload a verification document
      {:ok, key} = Storage.upload(:private, "verification-docs/providers/123/doc.pdf", binary)

      # Get signed URL for private file (5 min expiry)
      {:ok, signed_url} = Storage.signed_url(:private, key, 300)

      # Delete a file
      :ok = Storage.delete(:public, "logos/providers/123/logo.png")
  """

  @doc """
  Upload a file to storage.

  Returns public URL for `:public` bucket, storage key for `:private` bucket.
  """
  @spec upload(atom(), String.t(), binary(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def upload(bucket_type, path, binary, opts \\ []) do
    adapter(opts).upload(bucket_type, path, binary, opts)
  end

  @doc """
  Generate a signed URL for a private file.

  The URL expires after `expires_in_seconds`.
  """
  @spec signed_url(atom(), String.t(), pos_integer(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def signed_url(bucket_type, key, expires_in_seconds, opts \\ []) do
    adapter(opts).signed_url(bucket_type, key, expires_in_seconds, opts)
  end

  @doc """
  Check if a file exists in storage.
  """
  @spec file_exists?(atom(), String.t(), keyword()) :: {:ok, boolean()} | {:error, term()}
  def file_exists?(bucket_type, key, opts \\ []) do
    adapter(opts).file_exists?(bucket_type, key, opts)
  end

  @doc """
  Delete a file from storage.
  """
  @spec delete(atom(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete(bucket_type, key, opts \\ []) do
    adapter(opts).delete(bucket_type, key, opts)
  end

  # Trigger: adapter option is provided in opts
  # Why: allows tests to inject a specific adapter instance for isolation
  # Outcome: uses the provided adapter instead of the configured one
  defp adapter(opts) do
    Keyword.get_lazy(opts, :adapter, fn ->
      Application.get_env(:klass_hero, :storage)[:adapter]
    end)
  end
end
