defmodule KlassHero.Shared.StorageTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter
  alias KlassHero.Shared.Storage

  # Trigger: each test needs an isolated Agent instance for the stub adapter
  # Why: async tests would conflict if sharing a single global Agent
  # Outcome: each test gets its own Agent PID via a unique name
  setup do
    # Generate a unique name for this test's Agent to enable async tests
    agent_name = :"storage_test_#{System.unique_integer([:positive])}"
    {:ok, _pid} = StubStorageAdapter.start_link(name: agent_name)
    %{agent: agent_name}
  end

  describe "upload/4" do
    test "delegates to configured adapter", %{agent: agent} do
      result =
        Storage.upload(:public, "logos/test.png", "binary",
          adapter: StubStorageAdapter,
          agent: agent
        )

      assert {:ok, "stub://public/logos/test.png"} = result
    end
  end

  describe "signed_url/4" do
    test "delegates to configured adapter", %{agent: agent} do
      result =
        Storage.signed_url(:private, "docs/test.pdf", 300,
          adapter: StubStorageAdapter,
          agent: agent
        )

      assert {:ok, url} = result
      assert url =~ "stub://signed/"
    end
  end

  describe "delete/3" do
    test "delegates to configured adapter", %{agent: agent} do
      Storage.upload(:public, "logos/test.png", "binary",
        adapter: StubStorageAdapter,
        agent: agent
      )

      assert :ok =
               Storage.delete(:public, "logos/test.png",
                 adapter: StubStorageAdapter,
                 agent: agent
               )
    end
  end
end
