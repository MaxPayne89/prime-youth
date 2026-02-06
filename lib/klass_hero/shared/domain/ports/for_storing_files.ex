defmodule KlassHero.Shared.Domain.Ports.ForStoringFiles do
  @moduledoc """
  Port for file storage operations.

  Supports two bucket types:
  - `:public` — files served directly via URL (logos, program images)
  - `:private` — files require signed URLs (verification docs)
  """

  @type bucket_type :: :public | :private
  @type path :: String.t()
  @type binary_data :: binary()
  @type url :: String.t()
  @type key :: String.t()
  @type error_reason ::
          :upload_failed | :signed_url_failed | :file_not_found | :invalid_bucket | term()

  @doc """
  Upload a file to storage.

  Returns the storage key (for private bucket) or public URL (for public bucket).
  """
  @callback upload(bucket_type(), path(), binary_data(), keyword()) ::
              {:ok, url() | key()} | {:error, error_reason()}

  @doc """
  Generate a signed URL for accessing a private file.

  The URL expires after `expires_in_seconds`.
  """
  @callback signed_url(bucket_type(), key(), pos_integer(), keyword()) ::
              {:ok, url()} | {:error, error_reason()}

  @doc """
  Delete a file from storage.
  """
  @callback delete(bucket_type(), key(), keyword()) :: :ok | {:error, error_reason()}
end
