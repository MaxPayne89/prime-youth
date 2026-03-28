defmodule KlassHero.Shared.FeatureFlagsTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.FeatureFlags.StubFeatureFlagsAdapter
  alias KlassHero.Shared.FeatureFlags

  setup do
    agent_name = :"feature_flags_test_#{System.unique_integer([:positive])}"
    {:ok, _pid} = StubFeatureFlagsAdapter.start_link(name: agent_name)
    %{opts: [adapter: StubFeatureFlagsAdapter, agent: agent_name]}
  end

  describe "enabled?/2" do
    test "returns false for unknown flag", %{opts: opts} do
      assert {:ok, false} = FeatureFlags.enabled?(:nonexistent, opts)
    end

    test "returns true for enabled flag", %{opts: opts} do
      StubFeatureFlagsAdapter.set_enabled(:my_flag, opts)

      assert {:ok, true} = FeatureFlags.enabled?(:my_flag, opts)
    end
  end

  describe "enabled?/3" do
    test "returns false for unknown flag with actor", %{opts: opts} do
      actor = %{id: 1}

      assert {:ok, false} = FeatureFlags.enabled?(:nonexistent, actor, opts)
    end

    test "returns true for enabled flag with actor", %{opts: opts} do
      StubFeatureFlagsAdapter.set_enabled(:my_flag, opts)
      actor = %{id: 1}

      assert {:ok, true} = FeatureFlags.enabled?(:my_flag, actor, opts)
    end
  end

  describe "enable/2 and disable/2" do
    test "enables a flag", %{opts: opts} do
      assert :ok = FeatureFlags.enable(:my_flag, opts)
      assert {:ok, true} = FeatureFlags.enabled?(:my_flag, opts)
    end

    test "disables a previously enabled flag", %{opts: opts} do
      FeatureFlags.enable(:my_flag, opts)

      assert :ok = FeatureFlags.disable(:my_flag, opts)
      assert {:ok, false} = FeatureFlags.enabled?(:my_flag, opts)
    end

    test "disabling an already disabled flag is a no-op", %{opts: opts} do
      assert :ok = FeatureFlags.disable(:my_flag, opts)
      assert {:ok, false} = FeatureFlags.enabled?(:my_flag, opts)
    end
  end
end
