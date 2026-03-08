defmodule KlassHero.Shared.Domain.Services.ActivityGoalCalculatorTest do
  @moduledoc """
  Tests for the ActivityGoalCalculator domain service.

  All tests are pure unit tests with no database dependencies.
  The service drives the weekly activity goal display on the parent dashboard.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Shared.Domain.Services.ActivityGoalCalculator

  describe "calculate/2 - return shape" do
    test "returns a map with current, target, percentage, and status keys" do
      result = ActivityGoalCalculator.calculate([])

      assert is_map(result)
      assert Map.has_key?(result, :current)
      assert Map.has_key?(result, :target)
      assert Map.has_key?(result, :percentage)
      assert Map.has_key?(result, :status)
    end

    test "uses default target of 5 when no option given" do
      result = ActivityGoalCalculator.calculate([])
      assert result.target == 5
    end

    test "respects custom target option" do
      result = ActivityGoalCalculator.calculate([], target: 10)
      assert result.target == 10
    end
  end

  describe "calculate/2 - session counting with list sessions" do
    test "returns current=0 for empty children list" do
      assert ActivityGoalCalculator.calculate([]).current == 0
    end

    test "counts sessions from a single child with list sessions" do
      child = %{sessions: [:s1, :s2, :s3]}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 3
    end

    test "sums session counts across multiple children with list sessions" do
      children = [
        %{sessions: [:s1, :s2]},
        %{sessions: [:s3, :s4, :s5]}
      ]

      result = ActivityGoalCalculator.calculate(children)
      assert result.current == 5
    end

    test "counts 0 for a child with empty session list" do
      child = %{sessions: []}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 0
    end
  end

  describe "calculate/2 - session counting with string sessions" do
    test "parses 'current/total' string format" do
      child = %{sessions: "3/5"}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 3
    end

    test "extracts only the current count from string, ignores total" do
      child = %{sessions: "4/10"}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 4
    end

    test "returns 0 for string without slash separator" do
      child = %{sessions: "3"}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 0
    end

    test "returns 0 when current part of string is non-numeric" do
      child = %{sessions: "invalid/5"}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 0
    end

    test "returns 0 for empty string" do
      child = %{sessions: ""}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 0
    end
  end

  describe "calculate/2 - children without sessions field" do
    test "returns 0 for child with no sessions key" do
      child = %{name: "Alice"}
      result = ActivityGoalCalculator.calculate([child])
      assert result.current == 0
    end

    test "mixes children with and without sessions" do
      children = [
        %{sessions: [:s1, :s2]},
        %{name: "no sessions"},
        %{sessions: "1/5"}
      ]

      result = ActivityGoalCalculator.calculate(children)
      assert result.current == 3
    end
  end

  describe "calculate/2 - percentage calculation" do
    test "calculates percentage as integer division (current * 100 / target)" do
      # 3 sessions out of default target 5 = 60%
      children = [%{sessions: [:s1, :s2, :s3]}]
      result = ActivityGoalCalculator.calculate(children)
      assert result.percentage == 60
    end

    test "caps percentage at 100 when sessions exceed target" do
      children = [%{sessions: [:s1, :s2, :s3, :s4, :s5, :s6, :s7]}]
      result = ActivityGoalCalculator.calculate(children, target: 5)
      assert result.percentage == 100
    end

    test "returns 0 percentage for zero sessions" do
      result = ActivityGoalCalculator.calculate([])
      assert result.percentage == 0
    end

    test "returns 0 percentage when target is 0 (avoids division by zero)" do
      children = [%{sessions: [:s1, :s2]}]
      result = ActivityGoalCalculator.calculate(children, target: 0)
      assert result.percentage == 0
    end
  end

  describe "calculate/2 - status thresholds" do
    test "returns :achieved when percentage is exactly 100" do
      children = [%{sessions: [:s1, :s2, :s3, :s4, :s5]}]
      result = ActivityGoalCalculator.calculate(children, target: 5)
      assert result.status == :achieved
    end

    test "returns :achieved when percentage exceeds 100 (capped)" do
      children = [%{sessions: Enum.map(1..10, &"s#{&1}")}]
      result = ActivityGoalCalculator.calculate(children, target: 5)
      assert result.status == :achieved
    end

    test "returns :almost_there when percentage is exactly 80" do
      # 4 out of 5 = 80%
      children = [%{sessions: [:s1, :s2, :s3, :s4]}]
      result = ActivityGoalCalculator.calculate(children, target: 5)
      assert result.percentage == 80
      assert result.status == :almost_there
    end

    test "returns :almost_there for percentages between 80 and 99" do
      # 9 out of 10 = 90%
      children = [%{sessions: Enum.map(1..9, &"s#{&1}")}]
      result = ActivityGoalCalculator.calculate(children, target: 10)
      assert result.percentage == 90
      assert result.status == :almost_there
    end

    test "returns :in_progress when percentage is below 80" do
      # 3 out of 5 = 60%
      children = [%{sessions: [:s1, :s2, :s3]}]
      result = ActivityGoalCalculator.calculate(children, target: 5)
      assert result.status == :in_progress
    end

    test "returns :in_progress for empty children list" do
      result = ActivityGoalCalculator.calculate([])
      assert result.status == :in_progress
    end
  end
end
