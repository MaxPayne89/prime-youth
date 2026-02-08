defmodule KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapterTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter

  setup do
    name = :"stub_storage_#{System.unique_integer([:positive])}"
    {:ok, pid} = StubStorageAdapter.start_link(name: name)
    %{agent: pid}
  end

  describe "upload/4" do
    test "stores file and returns stub URL for public bucket", %{agent: agent} do
      result =
        StubStorageAdapter.upload(:public, "logos/test.png", "binary_data", agent: agent)

      assert {:ok, url} = result
      assert url == "stub://public/logos/test.png"
    end

    test "stores file and returns key for private bucket", %{agent: agent} do
      result =
        StubStorageAdapter.upload(:private, "docs/test.pdf", "binary_data", agent: agent)

      assert {:ok, key} = result
      assert key == "docs/test.pdf"
    end

    test "can retrieve uploaded file", %{agent: agent} do
      StubStorageAdapter.upload(:public, "logos/test.png", "binary_data", agent: agent)

      assert {:ok, "binary_data"} =
               StubStorageAdapter.get_uploaded(:public, "logos/test.png", agent: agent)
    end
  end

  describe "signed_url/3" do
    test "returns signed URL for existing file", %{agent: agent} do
      StubStorageAdapter.upload(:private, "docs/test.pdf", "binary_data", agent: agent)
      result = StubStorageAdapter.signed_url(:private, "docs/test.pdf", 300, agent: agent)

      assert {:ok, url} = result
      assert url =~ "stub://signed/docs/test.pdf"
      assert url =~ "expires=300"
    end

    test "returns error for nonexistent file", %{agent: agent} do
      result = StubStorageAdapter.signed_url(:private, "docs/missing.pdf", 300, agent: agent)

      assert {:error, :file_not_found} = result
    end
  end

  describe "delete/2" do
    test "removes file from storage", %{agent: agent} do
      StubStorageAdapter.upload(:public, "logos/test.png", "binary_data", agent: agent)

      assert :ok = StubStorageAdapter.delete(:public, "logos/test.png", agent: agent)

      assert {:error, :file_not_found} =
               StubStorageAdapter.get_uploaded(:public, "logos/test.png", agent: agent)
    end
  end
end
