# Verification Infrastructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable provider verification through document uploads, admin review workflows, and verified-only program creation.

**Architecture:** Storage infrastructure in Shared context (port + adapter pattern). Verification documents and provider updates in Identity context. Admin pages with role-based access. Event-driven projection in Program Catalog for verification checks.

**Tech Stack:** Elixir, Phoenix LiveView, ExAws S3, MinIO (test), Tigris (prod), PostgreSQL

---

## Phase 1: Storage Infrastructure

### Task 1: Add Storage Dependencies

**Files:**
- Modify: `mix.exs`

**Step 1: Add dependencies**

Add to `deps` function in `mix.exs`:

```elixir
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.5"},
{:sweet_xml, "~> 0.7"},
```

**Step 2: Fetch dependencies**

Run: `mix deps.get`
Expected: Dependencies fetched successfully

**Step 3: Commit**

```bash
git add mix.exs mix.lock
git commit -m "deps: add ex_aws and ex_aws_s3 for object storage"
```

---

### Task 2: Storage Port Definition

**Files:**
- Create: `lib/klass_hero/shared/domain/ports/for_storing_files.ex`

**Step 1: Write the port behaviour**

```elixir
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
  @type error_reason :: :upload_failed | :file_not_found | :invalid_bucket | term()

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
  @callback signed_url(bucket_type(), key(), pos_integer()) ::
              {:ok, url()} | {:error, error_reason()}

  @doc """
  Delete a file from storage.
  """
  @callback delete(bucket_type(), key()) :: :ok | {:error, error_reason()}
end
```

**Step 2: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors

**Step 3: Commit**

```bash
git add lib/klass_hero/shared/domain/ports/for_storing_files.ex
git commit -m "feat(shared): add ForStoringFiles port for object storage"
```

---

### Task 3: Stub Storage Adapter for Tests

**Files:**
- Create: `lib/klass_hero/shared/adapters/driven/storage/stub_storage_adapter.ex`
- Create: `test/klass_hero/shared/adapters/driven/storage/stub_storage_adapter_test.exs`

**Step 1: Write the test**

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapterTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter

  setup do
    {:ok, pid} = StubStorageAdapter.start_link([])
    %{adapter: pid}
  end

  describe "upload/4" do
    test "stores file and returns stub URL for public bucket", %{adapter: adapter} do
      result = StubStorageAdapter.upload(:public, "logos/test.png", "binary_data", adapter: adapter)

      assert {:ok, url} = result
      assert url == "stub://public/logos/test.png"
    end

    test "stores file and returns key for private bucket", %{adapter: adapter} do
      result = StubStorageAdapter.upload(:private, "docs/test.pdf", "binary_data", adapter: adapter)

      assert {:ok, key} = result
      assert key == "docs/test.pdf"
    end

    test "can retrieve uploaded file", %{adapter: adapter} do
      StubStorageAdapter.upload(:public, "logos/test.png", "binary_data", adapter: adapter)

      assert {:ok, "binary_data"} = StubStorageAdapter.get_uploaded(:public, "logos/test.png", adapter: adapter)
    end
  end

  describe "signed_url/3" do
    test "returns signed URL with expiration", %{adapter: adapter} do
      result = StubStorageAdapter.signed_url(:private, "docs/test.pdf", 300, adapter: adapter)

      assert {:ok, url} = result
      assert url =~ "stub://signed/docs/test.pdf"
      assert url =~ "expires=300"
    end
  end

  describe "delete/2" do
    test "removes file from storage", %{adapter: adapter} do
      StubStorageAdapter.upload(:public, "logos/test.png", "binary_data", adapter: adapter)

      assert :ok = StubStorageAdapter.delete(:public, "logos/test.png", adapter: adapter)
      assert {:error, :file_not_found} = StubStorageAdapter.get_uploaded(:public, "logos/test.png", adapter: adapter)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/shared/adapters/driven/storage/stub_storage_adapter_test.exs`
Expected: FAIL with module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter do
  @moduledoc """
  In-memory stub adapter for testing file storage operations.

  Stores files in an Agent for test assertions.
  """

  use Agent

  @behaviour KlassHero.Shared.Domain.Ports.ForStoringFiles

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{} end, name: name)
  end

  @impl true
  def upload(bucket_type, path, binary, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, __MODULE__)
    key = make_key(bucket_type, path)

    Agent.update(adapter, fn state ->
      Map.put(state, key, binary)
    end)

    case bucket_type do
      :public -> {:ok, "stub://public/#{path}"}
      :private -> {:ok, path}
    end
  end

  @impl true
  def signed_url(_bucket_type, key, expires_in, opts \\ []) do
    _adapter = Keyword.get(opts, :adapter, __MODULE__)
    {:ok, "stub://signed/#{key}?expires=#{expires_in}"}
  end

  @impl true
  def delete(bucket_type, path, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, __MODULE__)
    key = make_key(bucket_type, path)

    Agent.update(adapter, fn state ->
      Map.delete(state, key)
    end)

    :ok
  end

  @doc """
  Test helper to retrieve uploaded file content.
  """
  def get_uploaded(bucket_type, path, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, __MODULE__)
    key = make_key(bucket_type, path)

    case Agent.get(adapter, fn state -> Map.get(state, key) end) do
      nil -> {:error, :file_not_found}
      binary -> {:ok, binary}
    end
  end

  @doc """
  Test helper to clear all stored files.
  """
  def clear(opts \\ []) do
    adapter = Keyword.get(opts, :adapter, __MODULE__)
    Agent.update(adapter, fn _state -> %{} end)
  end

  defp make_key(bucket_type, path), do: "#{bucket_type}:#{path}"
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/shared/adapters/driven/storage/stub_storage_adapter_test.exs`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero/shared/adapters/driven/storage/stub_storage_adapter.ex \
        test/klass_hero/shared/adapters/driven/storage/stub_storage_adapter_test.exs
git commit -m "feat(shared): add StubStorageAdapter for testing"
```

---

### Task 4: S3 Storage Adapter

**Files:**
- Create: `lib/klass_hero/shared/adapters/driven/storage/s3_storage_adapter.ex`
- Modify: `config/config.exs`
- Modify: `config/runtime.exs`
- Modify: `config/test.exs`

**Step 1: Write the S3 adapter**

```elixir
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
      ExAws.S3.presigned_url(ex_aws_config(), :get, bucket, key,
        expires_in: expires_in
      )

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
```

**Step 2: Add storage configuration**

Add to `config/config.exs` after the existing config blocks:

```elixir
# Storage configuration (defaults, overridden per environment)
config :klass_hero, :storage,
  adapter: KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapter,
  public_bucket: "klass-hero-dev-public",
  private_bucket: "klass-hero-dev-private"
```

Add to `config/test.exs`:

```elixir
# Use stub adapter for tests by default
config :klass_hero, :storage,
  adapter: KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter,
  public_bucket: "test-public",
  private_bucket: "test-private"
```

Add to `config/runtime.exs` inside the `if config_env() == :prod do` block:

```elixir
# Storage configuration for production
config :klass_hero, :storage,
  adapter: KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapter,
  public_bucket: System.get_env("STORAGE_PUBLIC_BUCKET") || raise("STORAGE_PUBLIC_BUCKET not set"),
  private_bucket: System.get_env("STORAGE_PRIVATE_BUCKET") || raise("STORAGE_PRIVATE_BUCKET not set"),
  endpoint: System.get_env("STORAGE_ENDPOINT"),
  access_key_id: System.get_env("STORAGE_ACCESS_KEY_ID") || raise("STORAGE_ACCESS_KEY_ID not set"),
  secret_access_key: System.get_env("STORAGE_SECRET_ACCESS_KEY") || raise("STORAGE_SECRET_ACCESS_KEY not set")
```

**Step 3: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add lib/klass_hero/shared/adapters/driven/storage/s3_storage_adapter.ex \
        config/config.exs config/runtime.exs config/test.exs
git commit -m "feat(shared): add S3StorageAdapter with Tigris/MinIO support"
```

---

### Task 5: Storage Facade

**Files:**
- Create: `lib/klass_hero/shared/storage.ex`
- Create: `test/klass_hero/shared/storage_test.exs`

**Step 1: Write the test**

```elixir
defmodule KlassHero.Shared.StorageTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Storage
  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter

  setup do
    {:ok, pid} = StubStorageAdapter.start_link([])
    %{adapter: pid}
  end

  describe "upload/4" do
    test "delegates to configured adapter", %{adapter: adapter} do
      result = Storage.upload(:public, "logos/test.png", "binary", adapter: adapter)

      assert {:ok, "stub://public/logos/test.png"} = result
    end
  end

  describe "signed_url/3" do
    test "delegates to configured adapter", %{adapter: adapter} do
      result = Storage.signed_url(:private, "docs/test.pdf", 300, adapter: adapter)

      assert {:ok, url} = result
      assert url =~ "stub://signed/"
    end
  end

  describe "delete/3" do
    test "delegates to configured adapter", %{adapter: adapter} do
      Storage.upload(:public, "logos/test.png", "binary", adapter: adapter)

      assert :ok = Storage.delete(:public, "logos/test.png", adapter: adapter)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/shared/storage_test.exs`
Expected: FAIL with module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.Shared.Storage do
  @moduledoc """
  Public API for file storage operations.

  Delegates to the configured storage adapter (S3 in prod, Stub in tests).

  ## Bucket Types

  - `:public` — files accessible via direct URL (logos, program images)
  - `:private` — files require signed URLs with expiration (verification docs)

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
  def upload(bucket_type, path, binary, opts \\ []) do
    adapter(opts).upload(bucket_type, path, binary, opts)
  end

  @doc """
  Generate a signed URL for a private file.

  The URL expires after `expires_in_seconds`.
  """
  def signed_url(bucket_type, key, expires_in_seconds, opts \\ []) do
    adapter(opts).signed_url(bucket_type, key, expires_in_seconds, opts)
  end

  @doc """
  Delete a file from storage.
  """
  def delete(bucket_type, key, opts \\ []) do
    adapter(opts).delete(bucket_type, key, opts)
  end

  defp adapter(opts) do
    Keyword.get_lazy(opts, :adapter, fn ->
      Application.get_env(:klass_hero, :storage)[:adapter]
    end)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/shared/storage_test.exs`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero/shared/storage.ex test/klass_hero/shared/storage_test.exs
git commit -m "feat(shared): add Storage facade for file operations"
```

---

### Task 6: Docker MinIO Setup

**Files:**
- Modify: `docker-compose.yml`

**Step 1: Add MinIO service**

Add to `docker-compose.yml` after the `postgres` service:

```yaml
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 5s
      timeout: 5s
      retries: 5
```

Add to the `volumes` section:

```yaml
  minio_data:
```

**Step 2: Start MinIO**

Run: `docker compose up -d minio`
Expected: MinIO container starts

**Step 3: Verify MinIO is accessible**

Run: `curl -s http://localhost:9000/minio/health/live`
Expected: Returns empty response (200 OK)

**Step 4: Commit**

```bash
git add docker-compose.yml
git commit -m "infra: add MinIO to docker-compose for storage testing"
```

---

### Task 7: Integration Test for S3 Adapter

**Files:**
- Create: `test/klass_hero/shared/adapters/driven/storage/s3_storage_adapter_integration_test.exs`
- Create: `test/support/storage_integration_case.ex`

**Step 1: Write integration test case helper**

```elixir
defmodule KlassHero.StorageIntegrationCase do
  @moduledoc """
  Test case for storage integration tests using MinIO.

  These tests require MinIO running via docker-compose.
  Tag tests with `@tag :integration` to run them.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

      alias KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapter

      def minio_config do
        [
          adapter: S3StorageAdapter,
          public_bucket: "test-public",
          private_bucket: "test-private",
          endpoint: "http://localhost:9000",
          access_key_id: "minioadmin",
          secret_access_key: "minioadmin"
        ]
      end

      def setup_minio_buckets do
        config = minio_config()
        Application.put_env(:klass_hero, :storage, config)

        # Create buckets if they don't exist
        ex_aws_config = [
          access_key_id: config[:access_key_id],
          secret_access_key: config[:secret_access_key],
          host: "localhost",
          port: 9000,
          scheme: "http://"
        ]

        ExAws.S3.put_bucket(config[:public_bucket], "us-east-1")
        |> ExAws.request(ex_aws_config)

        ExAws.S3.put_bucket(config[:private_bucket], "us-east-1")
        |> ExAws.request(ex_aws_config)

        :ok
      end
    end
  end
end
```

**Step 2: Write the integration test**

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapterIntegrationTest do
  use KlassHero.StorageIntegrationCase

  @moduletag :integration

  setup do
    setup_minio_buckets()
    :ok
  end

  describe "upload/4" do
    test "uploads file to public bucket and returns URL" do
      path = "logos/test-#{System.unique_integer()}.png"
      binary = "test image content"

      assert {:ok, url} = S3StorageAdapter.upload(:public, path, binary)
      assert url =~ "test-public"
      assert url =~ path
    end

    test "uploads file to private bucket and returns key" do
      path = "docs/test-#{System.unique_integer()}.pdf"
      binary = "test document content"

      assert {:ok, key} = S3StorageAdapter.upload(:private, path, binary)
      assert key == path
    end
  end

  describe "signed_url/3" do
    test "generates signed URL for private file" do
      path = "docs/test-#{System.unique_integer()}.pdf"
      S3StorageAdapter.upload(:private, path, "test content")

      assert {:ok, url} = S3StorageAdapter.signed_url(:private, path, 300)
      assert url =~ path
      assert url =~ "X-Amz-Signature"
    end
  end

  describe "delete/2" do
    test "deletes file from storage" do
      path = "logos/test-#{System.unique_integer()}.png"
      S3StorageAdapter.upload(:public, path, "test content")

      assert :ok = S3StorageAdapter.delete(:public, path)
    end
  end
end
```

**Step 3: Run integration tests**

Run: `mix test test/klass_hero/shared/adapters/driven/storage/s3_storage_adapter_integration_test.exs --include integration`
Expected: All tests pass (requires MinIO running)

**Step 4: Commit**

```bash
git add test/support/storage_integration_case.ex \
        test/klass_hero/shared/adapters/driven/storage/s3_storage_adapter_integration_test.exs
git commit -m "test(shared): add S3 integration tests with MinIO"
```

---

## Phase 2: Admin Infrastructure

### Task 8: Add is_admin Field to User

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_is_admin_to_users.exs` (use `mix ecto.gen.migration`)
- Modify: `lib/klass_hero/accounts/user.ex`

**Step 1: Generate migration**

Run: `mix ecto.gen.migration add_is_admin_to_users`
Expected: Creates migration file

**Step 2: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.AddIsAdminToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_admin, :boolean, default: false, null: false
    end

    create index(:users, [:is_admin], where: "is_admin = true")
  end
end
```

**Step 3: Update User schema**

Add to `lib/klass_hero/accounts/user.ex` in the schema block:

```elixir
field :is_admin, :boolean, default: false
```

**Step 4: Run migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully

**Step 5: Commit**

```bash
git add priv/repo/migrations/*_add_is_admin_to_users.exs lib/klass_hero/accounts/user.ex
git commit -m "feat(accounts): add is_admin field to users"
```

---

### Task 9: Admin Mount Hook

**Files:**
- Modify: `lib/klass_hero_web/user_auth.ex`
- Create: `test/klass_hero_web/user_auth_admin_test.exs`

**Step 1: Write the test**

```elixir
defmodule KlassHeroWeb.UserAuthAdminTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.AccountsFixtures

  describe "require_admin mount hook" do
    test "allows admin users to access admin pages", %{conn: conn} do
      user = AccountsFixtures.user_fixture(%{is_admin: true})
      conn = log_in_user(conn, user)

      # We'll test with a real admin route once it exists
      # For now, verify the hook logic works
      socket = %Phoenix.LiveView.Socket{
        assigns: %{current_scope: %KlassHero.Accounts.Scope{user: user}}
      }

      assert {:cont, _socket} = KlassHeroWeb.UserAuth.on_mount(:require_admin, %{}, %{}, socket)
    end

    test "redirects non-admin users", %{conn: conn} do
      user = AccountsFixtures.user_fixture(%{is_admin: false})

      socket = %Phoenix.LiveView.Socket{
        assigns: %{current_scope: %KlassHero.Accounts.Scope{user: user}}
      }

      assert {:halt, socket} = KlassHeroWeb.UserAuth.on_mount(:require_admin, %{}, %{}, socket)
      assert socket.redirected
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/user_auth_admin_test.exs`
Expected: FAIL with function clause error

**Step 3: Add require_admin hook**

Add to `lib/klass_hero_web/user_auth.ex`:

```elixir
def on_mount(:require_admin, _params, _session, socket) do
  case socket.assigns[:current_scope] do
    %{user: %{is_admin: true}} ->
      {:cont, socket}

    _ ->
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "You don't have access to that page.")
       |> Phoenix.LiveView.redirect(to: ~p"/")}
  end
end
```

**Step 4: Update fixtures**

Add to `test/support/fixtures/accounts_fixtures.ex` — update `user_fixture/1` to support `:is_admin`:

In the `valid_user_attributes` function, ensure the attrs are merged properly to support `is_admin`.

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero_web/user_auth_admin_test.exs`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/klass_hero_web/user_auth.ex test/klass_hero_web/user_auth_admin_test.exs \
        test/support/fixtures/accounts_fixtures.ex
git commit -m "feat(web): add require_admin mount hook"
```

---

### Task 10: Admin Router Scope

**Files:**
- Modify: `lib/klass_hero_web/router.ex`
- Create: `lib/klass_hero_web/live/admin/verifications_live.ex` (placeholder)

**Step 1: Add admin live_session**

Add to `lib/klass_hero_web/router.ex` after the existing live_sessions:

```elixir
live_session :require_admin,
  on_mount: [
    {KlassHeroWeb.UserAuth, :mount_current_scope},
    {KlassHeroWeb.UserAuth, :require_authenticated},
    {KlassHeroWeb.UserAuth, :require_admin}
  ] do
  scope "/admin", KlassHeroWeb.Admin do
    pipe_through :browser

    live "/verifications", VerificationsLive, :index
    live "/verifications/:id", VerificationsLive, :show
  end
end
```

**Step 2: Create placeholder LiveView**

```elixir
defmodule KlassHeroWeb.Admin.VerificationsLive do
  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-bold">Verifications</h1>
      <p class="text-gray-600">Admin verification management coming soon.</p>
    </div>
    """
  end
end
```

**Step 3: Verify routes compile**

Run: `mix compile`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add lib/klass_hero_web/router.ex lib/klass_hero_web/live/admin/verifications_live.ex
git commit -m "feat(web): add admin router scope with verifications route"
```

---

## Phase 3: Verification Documents (Identity Context)

### Task 11: Verification Documents Migration

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_verification_documents.exs`

**Step 1: Generate migration**

Run: `mix ecto.gen.migration create_verification_documents`
Expected: Creates migration file

**Step 2: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateVerificationDocuments do
  use Ecto.Migration

  def change do
    create table(:verification_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_profile_id, references(:provider_profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :document_type, :string, null: false
      add :file_url, :string, null: false
      add :original_filename, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :rejection_reason, :string
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:verification_documents, [:provider_profile_id])
    create index(:verification_documents, [:status])
    create index(:verification_documents, [:reviewed_by_id])
  end
end
```

**Step 3: Run migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully

**Step 4: Commit**

```bash
git add priv/repo/migrations/*_create_verification_documents.exs
git commit -m "db: add verification_documents table"
```

---

### Task 12: Verification Document Domain Model

**Files:**
- Create: `lib/klass_hero/identity/domain/models/verification_document.ex`
- Create: `test/klass_hero/identity/domain/models/verification_document_test.exs`

**Step 1: Write the test**

```elixir
defmodule KlassHero.Identity.Domain.Models.VerificationDocumentTest do
  use ExUnit.Case, async: true

  alias KlassHero.Identity.Domain.Models.VerificationDocument

  describe "new/1" do
    test "creates valid verification document" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "business_registration",
        file_url: "verification-docs/providers/123/doc.pdf",
        original_filename: "registration.pdf"
      }

      assert {:ok, doc} = VerificationDocument.new(attrs)
      assert doc.status == :pending
      assert doc.document_type == "business_registration"
    end

    test "rejects invalid status" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "business_registration",
        file_url: "path",
        original_filename: "doc.pdf",
        status: :invalid
      }

      assert {:error, errors} = VerificationDocument.new(attrs)
      assert :status in Keyword.keys(errors)
    end
  end

  describe "approve/2" do
    test "sets status to approved with reviewer" do
      {:ok, doc} = VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "insurance",
        file_url: "path",
        original_filename: "doc.pdf"
      })

      reviewer_id = Ecto.UUID.generate()
      {:ok, approved} = VerificationDocument.approve(doc, reviewer_id)

      assert approved.status == :approved
      assert approved.reviewed_by_id == reviewer_id
      assert approved.reviewed_at != nil
    end
  end

  describe "reject/3" do
    test "sets status to rejected with reason" do
      {:ok, doc} = VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "insurance",
        file_url: "path",
        original_filename: "doc.pdf"
      })

      reviewer_id = Ecto.UUID.generate()
      {:ok, rejected} = VerificationDocument.reject(doc, reviewer_id, "Document expired")

      assert rejected.status == :rejected
      assert rejected.rejection_reason == "Document expired"
      assert rejected.reviewed_by_id == reviewer_id
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/identity/domain/models/verification_document_test.exs`
Expected: FAIL with module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.Identity.Domain.Models.VerificationDocument do
  @moduledoc """
  Domain model for provider verification documents.

  Represents a document submitted by a provider for verification review.
  Documents go through a simple lifecycle: pending → approved | rejected
  """

  @enforce_keys [:id, :provider_profile_id, :document_type, :file_url, :original_filename]
  defstruct [
    :id,
    :provider_profile_id,
    :document_type,
    :file_url,
    :original_filename,
    :rejection_reason,
    :reviewed_by_id,
    :reviewed_at,
    :inserted_at,
    :updated_at,
    status: :pending
  ]

  @type status :: :pending | :approved | :rejected

  @type t :: %__MODULE__{
          id: String.t(),
          provider_profile_id: String.t(),
          document_type: String.t(),
          file_url: String.t(),
          original_filename: String.t(),
          status: status(),
          rejection_reason: String.t() | nil,
          reviewed_by_id: String.t() | nil,
          reviewed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @valid_statuses [:pending, :approved, :rejected]
  @valid_document_types ["business_registration", "insurance_certificate", "id_document", "tax_certificate", "other"]

  @doc """
  Create a new verification document.
  """
  def new(attrs) when is_map(attrs) do
    with {:ok, validated} <- validate(attrs) do
      {:ok,
       %__MODULE__{
         id: validated.id,
         provider_profile_id: validated.provider_profile_id,
         document_type: validated.document_type,
         file_url: validated.file_url,
         original_filename: validated.original_filename,
         status: Map.get(validated, :status, :pending),
         inserted_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Approve a pending document.
  """
  def approve(%__MODULE__{status: :pending} = doc, reviewer_id) do
    {:ok,
     %{
       doc
       | status: :approved,
         reviewed_by_id: reviewer_id,
         reviewed_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
     }}
  end

  def approve(%__MODULE__{}, _reviewer_id) do
    {:error, :document_not_pending}
  end

  @doc """
  Reject a pending document with a reason.
  """
  def reject(%__MODULE__{status: :pending} = doc, reviewer_id, reason) when is_binary(reason) do
    {:ok,
     %{
       doc
       | status: :rejected,
         rejection_reason: reason,
         reviewed_by_id: reviewer_id,
         reviewed_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
     }}
  end

  def reject(%__MODULE__{}, _reviewer_id, _reason) do
    {:error, :document_not_pending}
  end

  defp validate(attrs) do
    errors =
      []
      |> validate_required(attrs, :id)
      |> validate_required(attrs, :provider_profile_id)
      |> validate_required(attrs, :document_type)
      |> validate_required(attrs, :file_url)
      |> validate_required(attrs, :original_filename)
      |> validate_status(attrs)
      |> validate_document_type(attrs)

    case errors do
      [] -> {:ok, attrs}
      errors -> {:error, errors}
    end
  end

  defp validate_required(errors, attrs, key) do
    case Map.get(attrs, key) do
      nil -> [{key, "is required"} | errors]
      "" -> [{key, "is required"} | errors]
      _ -> errors
    end
  end

  defp validate_status(errors, attrs) do
    case Map.get(attrs, :status) do
      nil -> errors
      status when status in @valid_statuses -> errors
      _ -> [{:status, "must be one of: #{inspect(@valid_statuses)}"} | errors]
    end
  end

  defp validate_document_type(errors, attrs) do
    case Map.get(attrs, :document_type) do
      type when type in @valid_document_types -> errors
      _ -> [{:document_type, "must be one of: #{inspect(@valid_document_types)}"} | errors]
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/identity/domain/models/verification_document_test.exs`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero/identity/domain/models/verification_document.ex \
        test/klass_hero/identity/domain/models/verification_document_test.exs
git commit -m "feat(identity): add VerificationDocument domain model"
```

---

### Task 13: Verification Document Port

**Files:**
- Create: `lib/klass_hero/identity/domain/ports/for_storing_verification_documents.ex`

**Step 1: Write the port**

```elixir
defmodule KlassHero.Identity.Domain.Ports.ForStoringVerificationDocuments do
  @moduledoc """
  Port for verification document persistence operations.
  """

  alias KlassHero.Identity.Domain.Models.VerificationDocument

  @callback create(VerificationDocument.t()) ::
              {:ok, VerificationDocument.t()} | {:error, term()}

  @callback get(String.t()) ::
              {:ok, VerificationDocument.t()} | {:error, :not_found}

  @callback get_by_provider(String.t()) ::
              {:ok, [VerificationDocument.t()]}

  @callback update(VerificationDocument.t()) ::
              {:ok, VerificationDocument.t()} | {:error, term()}

  @callback list_pending() ::
              {:ok, [VerificationDocument.t()]}

  @callback list_by_status(VerificationDocument.status()) ::
              {:ok, [VerificationDocument.t()]}
end
```

**Step 2: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors

**Step 3: Commit**

```bash
git add lib/klass_hero/identity/domain/ports/for_storing_verification_documents.ex
git commit -m "feat(identity): add ForStoringVerificationDocuments port"
```

---

### Task 14: Verification Document Schema and Mapper

**Files:**
- Create: `lib/klass_hero/identity/adapters/driven/persistence/schemas/verification_document_schema.ex`
- Create: `lib/klass_hero/identity/adapters/driven/persistence/mappers/verification_document_mapper.ex`

**Step 1: Write the schema**

```elixir
defmodule KlassHero.Identity.Adapters.Driven.Persistence.Schemas.VerificationDocumentSchema do
  use Ecto.Schema
  import Ecto.Changeset

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "verification_documents" do
    field :document_type, :string
    field :file_url, :string
    field :original_filename, :string
    field :status, :string, default: "pending"
    field :rejection_reason, :string
    field :reviewed_at, :utc_datetime_usec

    belongs_to :provider_profile, ProviderProfileSchema
    belongs_to :reviewed_by, User

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:provider_profile_id, :document_type, :file_url, :original_filename]
  @optional_fields [:status, :rejection_reason, :reviewed_by_id, :reviewed_at]

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ["pending", "approved", "rejected"])
    |> validate_inclusion(:document_type, [
      "business_registration",
      "insurance_certificate",
      "id_document",
      "tax_certificate",
      "other"
    ])
    |> foreign_key_constraint(:provider_profile_id)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  def approve_changeset(schema, reviewer_id) do
    schema
    |> change(%{
      status: "approved",
      reviewed_by_id: reviewer_id,
      reviewed_at: DateTime.utc_now()
    })
  end

  def reject_changeset(schema, reviewer_id, reason) do
    schema
    |> change(%{
      status: "rejected",
      rejection_reason: reason,
      reviewed_by_id: reviewer_id,
      reviewed_at: DateTime.utc_now()
    })
  end
end
```

**Step 2: Write the mapper**

```elixir
defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.VerificationDocumentMapper do
  @moduledoc """
  Maps between VerificationDocument domain model and Ecto schema.
  """

  alias KlassHero.Identity.Domain.Models.VerificationDocument
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.VerificationDocumentSchema

  def to_domain(%VerificationDocumentSchema{} = schema) do
    %VerificationDocument{
      id: schema.id,
      provider_profile_id: schema.provider_profile_id,
      document_type: schema.document_type,
      file_url: schema.file_url,
      original_filename: schema.original_filename,
      status: String.to_existing_atom(schema.status),
      rejection_reason: schema.rejection_reason,
      reviewed_by_id: schema.reviewed_by_id,
      reviewed_at: schema.reviewed_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  def to_schema(%VerificationDocument{} = domain) do
    %{
      id: domain.id,
      provider_profile_id: domain.provider_profile_id,
      document_type: domain.document_type,
      file_url: domain.file_url,
      original_filename: domain.original_filename,
      status: Atom.to_string(domain.status),
      rejection_reason: domain.rejection_reason,
      reviewed_by_id: domain.reviewed_by_id,
      reviewed_at: domain.reviewed_at
    }
  end
end
```

**Step 3: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add lib/klass_hero/identity/adapters/driven/persistence/schemas/verification_document_schema.ex \
        lib/klass_hero/identity/adapters/driven/persistence/mappers/verification_document_mapper.ex
git commit -m "feat(identity): add VerificationDocument schema and mapper"
```

---

### Task 15: Verification Document Repository

**Files:**
- Create: `lib/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository.ex`
- Create: `test/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository_test.exs`

**Step 1: Write the test**

```elixir
defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Identity.Domain.Models.VerificationDocument
  alias KlassHero.IdentityFixtures

  describe "create/1" do
    test "persists verification document" do
      provider = IdentityFixtures.provider_profile_fixture()

      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: provider.id,
          document_type: "business_registration",
          file_url: "verification-docs/test.pdf",
          original_filename: "registration.pdf"
        })

      assert {:ok, created} = VerificationDocumentRepository.create(doc)
      assert created.id == doc.id
      assert created.status == :pending
    end
  end

  describe "get/1" do
    test "retrieves document by id" do
      provider = IdentityFixtures.provider_profile_fixture()
      {:ok, doc} = create_document(provider.id)

      assert {:ok, found} = VerificationDocumentRepository.get(doc.id)
      assert found.id == doc.id
    end

    test "returns error for non-existent document" do
      assert {:error, :not_found} = VerificationDocumentRepository.get(Ecto.UUID.generate())
    end
  end

  describe "get_by_provider/1" do
    test "returns all documents for provider" do
      provider = IdentityFixtures.provider_profile_fixture()
      {:ok, doc1} = create_document(provider.id, "business_registration")
      {:ok, doc2} = create_document(provider.id, "insurance_certificate")

      assert {:ok, docs} = VerificationDocumentRepository.get_by_provider(provider.id)
      assert length(docs) == 2
      assert Enum.any?(docs, &(&1.id == doc1.id))
      assert Enum.any?(docs, &(&1.id == doc2.id))
    end
  end

  describe "update/1" do
    test "updates document status" do
      provider = IdentityFixtures.provider_profile_fixture()
      {:ok, doc} = create_document(provider.id)

      reviewer_id = Ecto.UUID.generate()
      {:ok, approved} = VerificationDocument.approve(doc, reviewer_id)

      assert {:ok, updated} = VerificationDocumentRepository.update(approved)
      assert updated.status == :approved
    end
  end

  describe "list_pending/0" do
    test "returns only pending documents" do
      provider = IdentityFixtures.provider_profile_fixture()
      {:ok, pending} = create_document(provider.id)
      {:ok, approved_doc} = create_document(provider.id, "insurance_certificate")

      # Approve one document
      {:ok, approved} = VerificationDocument.approve(approved_doc, Ecto.UUID.generate())
      VerificationDocumentRepository.update(approved)

      assert {:ok, docs} = VerificationDocumentRepository.list_pending()
      assert length(docs) == 1
      assert hd(docs).id == pending.id
    end
  end

  defp create_document(provider_id, type \\ "business_registration") do
    {:ok, doc} =
      VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: provider_id,
        document_type: type,
        file_url: "verification-docs/test-#{System.unique_integer()}.pdf",
        original_filename: "document.pdf"
      })

    VerificationDocumentRepository.create(doc)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository_test.exs`
Expected: FAIL with module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository do
  @moduledoc """
  Ecto-based repository for verification documents.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringVerificationDocuments

  import Ecto.Query

  alias KlassHero.Repo
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.VerificationDocumentSchema
  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.VerificationDocumentMapper

  @impl true
  def create(document) do
    attrs = VerificationDocumentMapper.to_schema(document)

    %VerificationDocumentSchema{}
    |> VerificationDocumentSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, VerificationDocumentMapper.to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def get(id) do
    case Repo.get(VerificationDocumentSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, VerificationDocumentMapper.to_domain(schema)}
    end
  end

  @impl true
  def get_by_provider(provider_profile_id) do
    docs =
      VerificationDocumentSchema
      |> where([d], d.provider_profile_id == ^provider_profile_id)
      |> order_by([d], desc: d.inserted_at)
      |> Repo.all()
      |> Enum.map(&VerificationDocumentMapper.to_domain/1)

    {:ok, docs}
  end

  @impl true
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
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository_test.exs`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository.ex \
        test/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository_test.exs
git commit -m "feat(identity): add VerificationDocumentRepository"
```

---

## Phase 4: Verification Use Cases

### Task 16: Submit Verification Document Use Case

**Files:**
- Create: `lib/klass_hero/identity/application/use_cases/verification/submit_verification_document.ex`
- Create: `test/klass_hero/identity/application/use_cases/verification/submit_verification_document_test.exs`

**Step 1: Write the test**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Verification.SubmitVerificationDocumentTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Application.UseCases.Verification.SubmitVerificationDocument
  alias KlassHero.IdentityFixtures
  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter

  setup do
    {:ok, storage} = StubStorageAdapter.start_link([])
    provider = IdentityFixtures.provider_profile_fixture()
    %{provider: provider, storage: storage}
  end

  describe "execute/1" do
    test "uploads document and creates record", %{provider: provider, storage: storage} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "business_registration",
        file_binary: "pdf content here",
        original_filename: "registration.pdf",
        content_type: "application/pdf",
        storage_adapter: storage
      }

      assert {:ok, doc} = SubmitVerificationDocument.execute(params)
      assert doc.provider_profile_id == provider.id
      assert doc.document_type == "business_registration"
      assert doc.status == :pending
      assert doc.file_url =~ "verification-docs/providers/#{provider.id}"
    end

    test "rejects invalid document type", %{provider: provider, storage: storage} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "invalid_type",
        file_binary: "content",
        original_filename: "doc.pdf",
        content_type: "application/pdf",
        storage_adapter: storage
      }

      assert {:error, errors} = SubmitVerificationDocument.execute(params)
      assert :document_type in Keyword.keys(errors)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/identity/application/use_cases/verification/submit_verification_document_test.exs`
Expected: FAIL with module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Verification.SubmitVerificationDocument do
  @moduledoc """
  Use case for provider submitting a verification document.

  1. Uploads file to private storage bucket
  2. Creates verification document record with pending status
  """

  alias KlassHero.Identity.Domain.Models.VerificationDocument
  alias KlassHero.Shared.Storage

  def execute(params) do
    with {:ok, file_url} <- upload_file(params),
         {:ok, document} <- create_document(params, file_url),
         {:ok, persisted} <- persist_document(document) do
      {:ok, persisted}
    end
  end

  defp upload_file(params) do
    path = build_path(params.provider_profile_id, params.original_filename)
    opts = [
      content_type: params[:content_type] || "application/octet-stream",
      adapter: params[:storage_adapter]
    ]

    Storage.upload(:private, path, params.file_binary, opts)
  end

  defp build_path(provider_id, filename) do
    # Sanitize filename and add unique prefix
    safe_filename = String.replace(filename, ~r/[^a-zA-Z0-9._-]/, "_")
    timestamp = System.system_time(:millisecond)
    "verification-docs/providers/#{provider_id}/#{timestamp}_#{safe_filename}"
  end

  defp create_document(params, file_url) do
    VerificationDocument.new(%{
      id: Ecto.UUID.generate(),
      provider_profile_id: params.provider_profile_id,
      document_type: params.document_type,
      file_url: file_url,
      original_filename: params.original_filename
    })
  end

  defp persist_document(document) do
    repository().create(document)
  end

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_verification_documents] ||
      KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/identity/application/use_cases/verification/submit_verification_document_test.exs`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero/identity/application/use_cases/verification/submit_verification_document.ex \
        test/klass_hero/identity/application/use_cases/verification/submit_verification_document_test.exs
git commit -m "feat(identity): add SubmitVerificationDocument use case"
```

---

### Task 17: Approve and Reject Document Use Cases

**Files:**
- Create: `lib/klass_hero/identity/application/use_cases/verification/approve_verification_document.ex`
- Create: `lib/klass_hero/identity/application/use_cases/verification/reject_verification_document.ex`
- Create: `test/klass_hero/identity/application/use_cases/verification/document_review_test.exs`

**Step 1: Write the tests**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Verification.DocumentReviewTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Application.UseCases.Verification.ApproveVerificationDocument
  alias KlassHero.Identity.Application.UseCases.Verification.RejectVerificationDocument
  alias KlassHero.Identity.Domain.Models.VerificationDocument
  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.IdentityFixtures
  alias KlassHero.AccountsFixtures

  setup do
    provider = IdentityFixtures.provider_profile_fixture()
    admin = AccountsFixtures.user_fixture(%{is_admin: true})
    {:ok, doc} = create_pending_document(provider.id)
    %{provider: provider, admin: admin, document: doc}
  end

  describe "ApproveVerificationDocument.execute/1" do
    test "approves pending document", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id}

      assert {:ok, approved} = ApproveVerificationDocument.execute(params)
      assert approved.status == :approved
      assert approved.reviewed_by_id == admin.id
      assert approved.reviewed_at != nil
    end

    test "fails for non-existent document", %{admin: admin} do
      params = %{document_id: Ecto.UUID.generate(), reviewer_id: admin.id}

      assert {:error, :not_found} = ApproveVerificationDocument.execute(params)
    end
  end

  describe "RejectVerificationDocument.execute/1" do
    test "rejects pending document with reason", %{admin: admin, document: doc} do
      params = %{
        document_id: doc.id,
        reviewer_id: admin.id,
        reason: "Document is expired"
      }

      assert {:ok, rejected} = RejectVerificationDocument.execute(params)
      assert rejected.status == :rejected
      assert rejected.rejection_reason == "Document is expired"
    end

    test "requires rejection reason", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id, reason: ""}

      assert {:error, :reason_required} = RejectVerificationDocument.execute(params)
    end
  end

  defp create_pending_document(provider_id) do
    {:ok, doc} =
      VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: provider_id,
        document_type: "business_registration",
        file_url: "verification-docs/test.pdf",
        original_filename: "doc.pdf"
      })

    VerificationDocumentRepository.create(doc)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/identity/application/use_cases/verification/document_review_test.exs`
Expected: FAIL with module not found

**Step 3: Write ApproveVerificationDocument**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Verification.ApproveVerificationDocument do
  @moduledoc """
  Use case for admin approving a verification document.
  """

  alias KlassHero.Identity.Domain.Models.VerificationDocument

  def execute(%{document_id: document_id, reviewer_id: reviewer_id}) do
    with {:ok, document} <- get_document(document_id),
         {:ok, approved} <- VerificationDocument.approve(document, reviewer_id),
         {:ok, persisted} <- repository().update(approved) do
      {:ok, persisted}
    end
  end

  defp get_document(id) do
    repository().get(id)
  end

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_verification_documents] ||
      KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  end
end
```

**Step 4: Write RejectVerificationDocument**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Verification.RejectVerificationDocument do
  @moduledoc """
  Use case for admin rejecting a verification document with a reason.
  """

  alias KlassHero.Identity.Domain.Models.VerificationDocument

  def execute(%{document_id: document_id, reviewer_id: reviewer_id, reason: reason}) do
    with :ok <- validate_reason(reason),
         {:ok, document} <- get_document(document_id),
         {:ok, rejected} <- VerificationDocument.reject(document, reviewer_id, reason),
         {:ok, persisted} <- repository().update(rejected) do
      {:ok, persisted}
    end
  end

  defp validate_reason(reason) when is_binary(reason) and byte_size(reason) > 0, do: :ok
  defp validate_reason(_), do: {:error, :reason_required}

  defp get_document(id) do
    repository().get(id)
  end

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_verification_documents] ||
      KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  end
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/identity/application/use_cases/verification/document_review_test.exs`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/klass_hero/identity/application/use_cases/verification/*.ex \
        test/klass_hero/identity/application/use_cases/verification/document_review_test.exs
git commit -m "feat(identity): add document approval and rejection use cases"
```

---

### Task 18: Verify/Unverify Provider Use Cases

**Files:**
- Create: `lib/klass_hero/identity/application/use_cases/providers/verify_provider.ex`
- Create: `lib/klass_hero/identity/application/use_cases/providers/unverify_provider.ex`
- Create: `test/klass_hero/identity/application/use_cases/providers/provider_verification_test.exs`

**Step 1: Write the tests**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Providers.ProviderVerificationTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Application.UseCases.Providers.VerifyProvider
  alias KlassHero.Identity.Application.UseCases.Providers.UnverifyProvider
  alias KlassHero.IdentityFixtures
  alias KlassHero.AccountsFixtures

  setup do
    provider = IdentityFixtures.provider_profile_fixture()
    admin = AccountsFixtures.user_fixture(%{is_admin: true})
    %{provider: provider, admin: admin}
  end

  describe "VerifyProvider.execute/1" do
    test "sets provider as verified", %{provider: provider, admin: admin} do
      params = %{provider_id: provider.id, admin_id: admin.id}

      assert {:ok, verified} = VerifyProvider.execute(params)
      assert verified.verified == true
      assert verified.verified_at != nil
    end

    test "publishes integration event", %{provider: provider, admin: admin} do
      # Subscribe to integration events
      Phoenix.PubSub.subscribe(KlassHero.PubSub, "integration:identity:provider_verified")

      params = %{provider_id: provider.id, admin_id: admin.id}
      {:ok, _} = VerifyProvider.execute(params)

      assert_receive {:integration_event, %{provider_id: provider_id}}
      assert provider_id == provider.id
    end
  end

  describe "UnverifyProvider.execute/1" do
    test "sets provider as unverified", %{provider: provider, admin: admin} do
      # First verify
      VerifyProvider.execute(%{provider_id: provider.id, admin_id: admin.id})

      # Then unverify
      params = %{provider_id: provider.id, admin_id: admin.id}
      assert {:ok, unverified} = UnverifyProvider.execute(params)
      assert unverified.verified == false
      assert unverified.verified_at == nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/identity/application/use_cases/providers/provider_verification_test.exs`
Expected: FAIL with module not found

**Step 3: Write VerifyProvider**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Providers.VerifyProvider do
  @moduledoc """
  Use case for admin verifying a provider.

  Sets verified: true and publishes integration event.
  """

  alias KlassHero.Shared.EventPublishing

  def execute(%{provider_id: provider_id, admin_id: _admin_id}) do
    with {:ok, profile} <- get_profile(provider_id),
         {:ok, verified} <- verify_profile(profile),
         {:ok, persisted} <- save_profile(verified),
         :ok <- publish_event(persisted) do
      {:ok, persisted}
    end
  end

  defp get_profile(provider_id) do
    repository().get(provider_id)
  end

  defp verify_profile(profile) do
    {:ok,
     %{
       profile
       | verified: true,
         verified_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
     }}
  end

  defp save_profile(profile) do
    repository().update(profile)
  end

  defp publish_event(profile) do
    EventPublishing.publish(
      "integration:identity:provider_verified",
      {:integration_event, %{provider_id: profile.id}}
    )
  end

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_provider_profiles] ||
      KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  end
end
```

**Step 4: Write UnverifyProvider**

```elixir
defmodule KlassHero.Identity.Application.UseCases.Providers.UnverifyProvider do
  @moduledoc """
  Use case for admin revoking provider verification.
  """

  alias KlassHero.Shared.EventPublishing

  def execute(%{provider_id: provider_id, admin_id: _admin_id}) do
    with {:ok, profile} <- get_profile(provider_id),
         {:ok, unverified} <- unverify_profile(profile),
         {:ok, persisted} <- save_profile(unverified),
         :ok <- publish_event(persisted) do
      {:ok, persisted}
    end
  end

  defp get_profile(provider_id) do
    repository().get(provider_id)
  end

  defp unverify_profile(profile) do
    {:ok,
     %{
       profile
       | verified: false,
         verified_at: nil,
         updated_at: DateTime.utc_now()
     }}
  end

  defp save_profile(profile) do
    repository().update(profile)
  end

  defp publish_event(profile) do
    EventPublishing.publish(
      "integration:identity:provider_unverified",
      {:integration_event, %{provider_id: profile.id}}
    )
  end

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_provider_profiles] ||
      KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  end
end
```

**Step 5: Extend ProviderProfileRepository with update and get**

Add to the existing repository if not present:

```elixir
# In lib/klass_hero/identity/adapters/driven/persistence/repositories/provider_profile_repository.ex

def get(id) do
  case Repo.get(ProviderProfileSchema, id) do
    nil -> {:error, :not_found}
    schema -> {:ok, ProviderProfileMapper.to_domain(schema)}
  end
end

def update(profile) do
  case Repo.get(ProviderProfileSchema, profile.id) do
    nil ->
      {:error, :not_found}

    schema ->
      attrs = ProviderProfileMapper.to_schema(profile)

      schema
      |> ProviderProfileSchema.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated} -> {:ok, ProviderProfileMapper.to_domain(updated)}
        {:error, changeset} -> {:error, changeset}
      end
  end
end
```

**Step 6: Run test to verify it passes**

Run: `mix test test/klass_hero/identity/application/use_cases/providers/provider_verification_test.exs`
Expected: All tests pass

**Step 7: Commit**

```bash
git add lib/klass_hero/identity/application/use_cases/providers/*.ex \
        lib/klass_hero/identity/adapters/driven/persistence/repositories/provider_profile_repository.ex \
        test/klass_hero/identity/application/use_cases/providers/provider_verification_test.exs
git commit -m "feat(identity): add provider verify/unverify use cases with events"
```

---

## Phase 5: Identity Facade Updates

### Task 19: Update Identity Facade

**Files:**
- Modify: `lib/klass_hero/identity.ex`
- Modify: `config/config.exs`

**Step 1: Add verification document config**

Add to `config/config.exs` in the `:identity` config:

```elixir
for_storing_verification_documents: KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
```

**Step 2: Add facade functions**

Add to `lib/klass_hero/identity.ex`:

```elixir
# Verification Documents

@doc """
Submit a verification document for a provider.
"""
def submit_verification_document(params) do
  KlassHero.Identity.Application.UseCases.Verification.SubmitVerificationDocument.execute(params)
end

@doc """
Approve a verification document (admin only).
"""
def approve_verification_document(document_id, reviewer_id) do
  KlassHero.Identity.Application.UseCases.Verification.ApproveVerificationDocument.execute(%{
    document_id: document_id,
    reviewer_id: reviewer_id
  })
end

@doc """
Reject a verification document with reason (admin only).
"""
def reject_verification_document(document_id, reviewer_id, reason) do
  KlassHero.Identity.Application.UseCases.Verification.RejectVerificationDocument.execute(%{
    document_id: document_id,
    reviewer_id: reviewer_id,
    reason: reason
  })
end

@doc """
Get all verification documents for a provider.
"""
def get_provider_verification_documents(provider_profile_id) do
  verification_document_repository().get_by_provider(provider_profile_id)
end

@doc """
List all pending verification documents (admin).
"""
def list_pending_verification_documents do
  verification_document_repository().list_pending()
end

# Provider Verification

@doc """
Verify a provider (admin only).
"""
def verify_provider(provider_id, admin_id) do
  KlassHero.Identity.Application.UseCases.Providers.VerifyProvider.execute(%{
    provider_id: provider_id,
    admin_id: admin_id
  })
end

@doc """
Unverify a provider (admin only).
"""
def unverify_provider(provider_id, admin_id) do
  KlassHero.Identity.Application.UseCases.Providers.UnverifyProvider.execute(%{
    provider_id: provider_id,
    admin_id: admin_id
  })
end

@doc """
List all verified provider IDs (for projections).
"""
def list_verified_provider_ids do
  provider_profile_repository().list_verified_ids()
end

defp verification_document_repository do
  Application.get_env(:klass_hero, :identity)[:for_storing_verification_documents]
end
```

**Step 3: Add list_verified_ids to repository**

Add to `ProviderProfileRepository`:

```elixir
def list_verified_ids do
  ids =
    ProviderProfileSchema
    |> where([p], p.verified == true)
    |> select([p], p.id)
    |> Repo.all()

  {:ok, ids}
end
```

**Step 4: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors

**Step 5: Commit**

```bash
git add lib/klass_hero/identity.ex config/config.exs \
        lib/klass_hero/identity/adapters/driven/persistence/repositories/provider_profile_repository.ex
git commit -m "feat(identity): update facade with verification functions"
```

---

## Phase 6: Program Catalog Verification Projection

### Task 20: Verified Providers GenServer

**Files:**
- Create: `lib/klass_hero/program_catalog/adapters/driven/projections/verified_providers.ex`
- Create: `test/klass_hero/program_catalog/adapters/driven/projections/verified_providers_test.exs`

**Step 1: Write the test**

```elixir
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProvidersTest do
  use KlassHero.DataCase, async: false

  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
  alias KlassHero.IdentityFixtures

  setup do
    # Start with clean state
    if Process.whereis(VerifiedProviders), do: GenServer.stop(VerifiedProviders)
    {:ok, _pid} = VerifiedProviders.start_link([])
    :ok
  end

  describe "verified?/1" do
    test "returns false for unknown provider" do
      refute VerifiedProviders.verified?(Ecto.UUID.generate())
    end

    test "returns true after verification event" do
      provider_id = Ecto.UUID.generate()

      # Simulate integration event
      send(VerifiedProviders, {:integration_event, %{provider_id: provider_id}})

      # Give time for message processing
      Process.sleep(10)

      assert VerifiedProviders.verified?(provider_id)
    end

    test "returns false after unverification event" do
      provider_id = Ecto.UUID.generate()

      # Verify then unverify
      send(VerifiedProviders, {:integration_event, %{provider_id: provider_id}})
      Process.sleep(10)

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_unverified",
        {:integration_event, %{provider_id: provider_id}}
      )
      Process.sleep(10)

      refute VerifiedProviders.verified?(provider_id)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/projections/verified_providers_test.exs`
Expected: FAIL with module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders do
  @moduledoc """
  In-memory projection of verified provider IDs.

  Bootstraps from Identity context on startup, then stays in sync via
  integration events.
  """

  use GenServer

  require Logger

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Check if a provider is verified.
  """
  def verified?(provider_id, name \\ __MODULE__) do
    GenServer.call(name, {:verified?, provider_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to integration events
    Phoenix.PubSub.subscribe(KlassHero.PubSub, "integration:identity:provider_verified")
    Phoenix.PubSub.subscribe(KlassHero.PubSub, "integration:identity:provider_unverified")

    # Bootstrap from Identity context
    verified_ids = bootstrap_verified_ids()

    Logger.info("VerifiedProviders projection started",
      count: MapSet.size(verified_ids)
    )

    {:ok, %{verified_ids: verified_ids}}
  end

  @impl true
  def handle_call({:verified?, provider_id}, _from, state) do
    result = MapSet.member?(state.verified_ids, provider_id)
    {:reply, result, state}
  end

  @impl true
  def handle_info({:integration_event, %{provider_id: provider_id}}, state) do
    # This is a verification event (from the verified topic subscription)
    new_ids = MapSet.put(state.verified_ids, provider_id)

    Logger.debug("Provider verified in projection",
      provider_id: provider_id
    )

    {:noreply, %{state | verified_ids: new_ids}}
  end

  # Handle unverification separately via pattern matching on the topic
  # Since PubSub sends to both subscriptions, we need to handle both
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "integration:identity:provider_unverified", payload: %{provider_id: provider_id}}, state) do
    new_ids = MapSet.delete(state.verified_ids, provider_id)

    Logger.debug("Provider unverified in projection",
      provider_id: provider_id
    )

    {:noreply, %{state | verified_ids: new_ids}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp bootstrap_verified_ids do
    case KlassHero.Identity.list_verified_provider_ids() do
      {:ok, ids} ->
        MapSet.new(ids)

      {:error, reason} ->
        Logger.warning("Failed to bootstrap verified providers",
          reason: inspect(reason)
        )

        MapSet.new()
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/projections/verified_providers_test.exs`
Expected: All tests pass

**Step 5: Add to supervision tree**

Add to `lib/klass_hero/application.ex` children list:

```elixir
KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
```

**Step 6: Commit**

```bash
git add lib/klass_hero/program_catalog/adapters/driven/projections/verified_providers.ex \
        test/klass_hero/program_catalog/adapters/driven/projections/verified_providers_test.exs \
        lib/klass_hero/application.ex
git commit -m "feat(program_catalog): add VerifiedProviders projection with event sync"
```

---

## Phase 7: Web Layer (Remaining Tasks)

The remaining tasks cover the web layer implementation:

- **Task 21-23:** Provider Settings LiveView (business info form, logo upload, document upload)
- **Task 24-26:** Admin Verifications LiveView (list, show, actions)
- **Task 27:** Program creation guard in UI

These follow the same TDD pattern but involve more UI-specific code. The core infrastructure is complete after Phase 6.

---

## Pre-Commit Checklist

After completing all tasks:

```bash
mix compile --warnings-as-errors
mix format
mix test
```

All must pass before creating PR.
