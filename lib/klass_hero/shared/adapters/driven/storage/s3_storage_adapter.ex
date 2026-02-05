defmodule KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapter do
  @moduledoc """
  S3-compatible storage adapter using ExAws.

  Works with AWS S3, Tigris, MinIO, and other S3-compatible services.
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForStoringFiles

  require Logger

  @impl true
  def upload(bucket_type, path, binary, opts \\ []) do
    bucket = get_bucket(bucket_type)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    # Trigger: S3 upload operation requested
    # Why: ExAws handles S3-compatible API calls for us
    # Outcome: File stored in bucket, URL or key returned
    case ExAws.S3.put_object(bucket, path, binary, content_type: content_type)
         |> ExAws.request(ex_aws_config()) do
      {:ok, _response} ->
        case bucket_type do
          :public -> {:ok, public_url(bucket, path)}
          :private -> {:ok, path}
        end

      {:error, reason} ->
        Logger.error("S3 upload failed",
          bucket: bucket,
          path: path,
          error: inspect(reason)
        )

        {:error, :upload_failed}
    end
  end

  @impl true
  def signed_url(_bucket_type, key, expires_in, _opts \\ []) do
    bucket = get_bucket(:private)

    {:ok, url} =
      ExAws.S3.presigned_url(ex_aws_config(), :get, bucket, key, expires_in: expires_in)

    {:ok, url}
  end

  @impl true
  def delete(bucket_type, key, _opts \\ []) do
    bucket = get_bucket(bucket_type)

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request(ex_aws_config()) do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_bucket(:public), do: storage_config(:public_bucket)
  defp get_bucket(:private), do: storage_config(:private_bucket)

  defp public_url(bucket, path) do
    # Trigger: Public URL construction requested
    # Why: Different S3-compatible services have different URL patterns
    # Outcome: Appropriate public URL for the storage backend
    case storage_config(:endpoint) do
      nil ->
        # Standard S3/Tigris URL
        "https://#{bucket}.fly.storage.tigris.dev/#{path}"

      endpoint ->
        # MinIO or custom endpoint
        "#{endpoint}/#{bucket}/#{path}"
    end
  end

  defp storage_config(key) do
    Application.get_env(:klass_hero, :storage)[key]
  end

  defp ex_aws_config do
    config = Application.get_env(:klass_hero, :storage)

    base = [
      access_key_id: config[:access_key_id],
      secret_access_key: config[:secret_access_key]
    ]

    # Trigger: ExAws config construction
    # Why: Tigris uses S3-compatible API but different host; MinIO uses custom endpoint
    # Outcome: Properly configured ExAws for the target storage backend
    case config[:endpoint] do
      nil ->
        # Tigris uses S3-compatible API with custom host
        Keyword.merge(base,
          host: "fly.storage.tigris.dev",
          scheme: "https://"
        )

      endpoint ->
        # MinIO or custom endpoint
        uri = URI.parse(endpoint)

        Keyword.merge(base,
          host: uri.host,
          port: uri.port,
          scheme: "#{uri.scheme}://"
        )
    end
  end
end
