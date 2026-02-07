defmodule KlassHero.StorageIntegrationCase do
  @moduledoc """
  Test case for storage integration tests using MinIO.

  These tests require MinIO running via docker-compose.
  Tag tests with `@tag :integration` to run them.

  ## Usage

      use KlassHero.StorageIntegrationCase

  ## Running Integration Tests

      mix test --include integration

  ## Requirements

  MinIO must be running:

      docker compose up -d minio
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapter

      @moduletag :integration

      @doc """
      Returns MinIO configuration for tests.
      """
      def minio_config do
        [
          adapter: S3StorageAdapter,
          bucket: "klass-hero-test",
          endpoint: "http://localhost:9000",
          access_key_id: "minioadmin",
          secret_access_key: "minioadmin"
        ]
      end

      @doc """
      Sets up MinIO bucket for testing.

      Creates the klass-hero-test bucket if it doesn't exist.
      Also configures the application environment for storage.
      """
      def setup_minio_buckets do
        config = minio_config()
        Application.put_env(:klass_hero, :storage, config)

        ex_aws_config = [
          access_key_id: config[:access_key_id],
          secret_access_key: config[:secret_access_key],
          host: "localhost",
          port: 9000,
          scheme: "http://"
        ]

        # Trigger: Bucket creation for test isolation
        # Why: Each test run needs the bucket to exist for upload/download operations
        # Outcome: Single bucket exists, visibility controlled per-object via ACLs
        ExAws.S3.put_bucket(config[:bucket], "us-east-1")
        |> ExAws.request(ex_aws_config)

        :ok
      end
    end
  end
end
