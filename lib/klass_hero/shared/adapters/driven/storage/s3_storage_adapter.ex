defmodule KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapter do
  @moduledoc """
  S3-compatible storage adapter using ExAws.

  Works with AWS S3, Tigris, MinIO, and other S3-compatible services.
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForStoringFiles

  require Logger

  @impl true
  def upload(bucket_type, path, binary, opts) do
    bucket = get_bucket()
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    # Trigger: bucket_type is :public
    # Why: single bucket — visibility is controlled per-object via S3 ACLs
    # Outcome: public files are directly accessible, private files require signed URLs
    put_opts =
      case bucket_type do
        :public -> [content_type: content_type, acl: :public_read]
        :private -> [content_type: content_type]
      end

    ExAws.S3.put_object(bucket, path, binary, put_opts)
    |> ExAws.request(ex_aws_config())
    |> case do
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
  # Signed URLs are typically used for private files — public files are accessed
  # directly via their public URL, so bucket_type is intentionally ignored.
  def signed_url(_bucket_type, key, expires_in, _opts) do
    bucket = get_bucket()

    # presigned_url/5 requires config as a map, not keyword list
    config_map = ex_aws_config() |> Map.new()

    case ExAws.S3.presigned_url(config_map, :get, bucket, key, expires_in: expires_in) do
      {:ok, url} ->
        {:ok, url}

      {:error, reason} ->
        Logger.error("S3 presigned URL generation failed",
          bucket: bucket,
          key: key,
          error: inspect(reason)
        )

        {:error, :signed_url_failed}
    end
  end

  @impl true
  # Trigger: need to verify file exists before generating signed URL
  # Why: signed URLs succeed even for nonexistent files (just URL math), causing broken previews
  # Outcome: returns boolean so callers can skip URL generation for missing files
  def file_exists?(_bucket_type, key, _opts) do
    bucket = get_bucket()

    ExAws.S3.head_object(bucket, key)
    |> ExAws.request(ex_aws_config())
    |> case do
      {:ok, _} ->
        {:ok, true}

      {:error, {:http_error, 404, _}} ->
        {:ok, false}

      {:error, reason} ->
        Logger.error("S3 file existence check failed",
          bucket: bucket,
          key: key,
          error: inspect(reason)
        )

        {:error, :storage_unavailable}
    end
  end

  @impl true
  def delete(_bucket_type, key, _opts) do
    bucket = get_bucket()

    ExAws.S3.delete_object(bucket, key)
    |> ExAws.request(ex_aws_config())
    |> case do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.error("S3 delete failed",
          bucket: bucket,
          key: key,
          error: inspect(reason)
        )

        {:error, :delete_failed}
    end
  end

  defp get_bucket, do: storage_config(:bucket)

  defp public_url(bucket, path) do
    # Trigger: Public URL construction requested
    # Why: Different S3-compatible services have different URL patterns
    # Outcome: Appropriate public URL for the storage backend
    case storage_config(:endpoint) do
      nil ->
        # Production default: Fly.io Tigris (S3-compatible storage backend)
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

    # Trigger: ExAws config construction
    # Why: Tigris uses S3-compatible API but different host/region; MinIO uses custom endpoint
    # Outcome: Properly configured ExAws for the target storage backend
    case config[:endpoint] do
      nil ->
        # Tigris: region must be "auto" per Tigris docs for global bucket routing
        [
          access_key_id: config[:access_key_id],
          secret_access_key: config[:secret_access_key],
          region: "auto",
          host: "fly.storage.tigris.dev",
          scheme: "https://"
        ]

      endpoint ->
        # MinIO or custom endpoint
        uri = URI.parse(endpoint)

        [
          access_key_id: config[:access_key_id],
          secret_access_key: config[:secret_access_key],
          region: config[:region] || "us-east-1",
          host: uri.host,
          port: uri.port,
          scheme: "#{uri.scheme}://"
        ]
    end
  end
end
