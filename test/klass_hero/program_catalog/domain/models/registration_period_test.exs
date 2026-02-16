defmodule KlassHero.ProgramCatalog.Domain.Models.RegistrationPeriodTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.RegistrationPeriod

  describe "new/1" do
    test "creates with both dates" do
      assert {:ok, rp} =
               RegistrationPeriod.new(%{start_date: ~D[2026-03-01], end_date: ~D[2026-04-01]})

      assert rp.start_date == ~D[2026-03-01]
      assert rp.end_date == ~D[2026-04-01]
    end

    test "creates with only start_date" do
      assert {:ok, rp} = RegistrationPeriod.new(%{start_date: ~D[2026-03-01]})
      assert rp.start_date == ~D[2026-03-01]
      assert rp.end_date == nil
    end

    test "creates with only end_date" do
      assert {:ok, rp} = RegistrationPeriod.new(%{end_date: ~D[2026-04-01]})
      assert rp.start_date == nil
      assert rp.end_date == ~D[2026-04-01]
    end

    test "creates with both nil (always open)" do
      assert {:ok, rp} = RegistrationPeriod.new(%{})
      assert rp.start_date == nil
      assert rp.end_date == nil
    end

    test "rejects start_date after end_date" do
      assert {:error, errors} =
               RegistrationPeriod.new(%{start_date: ~D[2026-05-01], end_date: ~D[2026-03-01]})

      assert Enum.any?(errors, &String.contains?(&1, "before"))
    end

    test "rejects equal start_date and end_date" do
      assert {:error, errors} =
               RegistrationPeriod.new(%{start_date: ~D[2026-03-01], end_date: ~D[2026-03-01]})

      assert Enum.any?(errors, &String.contains?(&1, "before"))
    end
  end

  describe "status/1" do
    test "returns :always_open when both dates nil" do
      rp = %RegistrationPeriod{}
      assert RegistrationPeriod.status(rp) == :always_open
    end

    test "returns :upcoming when today is before start_date" do
      future = Date.add(Date.utc_today(), 30)
      rp = %RegistrationPeriod{start_date: future, end_date: Date.add(future, 60)}
      assert RegistrationPeriod.status(rp) == :upcoming
    end

    test "returns :open when today is between start and end" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: Date.add(today, -5), end_date: Date.add(today, 5)}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :open on the exact start_date" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: today, end_date: Date.add(today, 10)}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :open on the exact end_date" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: Date.add(today, -10), end_date: today}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :closed when today is after end_date" do
      past = Date.add(Date.utc_today(), -30)
      rp = %RegistrationPeriod{start_date: Date.add(past, -60), end_date: past}
      assert RegistrationPeriod.status(rp) == :closed
    end

    test "returns :open when only start_date set and today is past it" do
      past = Date.add(Date.utc_today(), -5)
      rp = %RegistrationPeriod{start_date: past}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :upcoming when only start_date set and today is before it" do
      future = Date.add(Date.utc_today(), 5)
      rp = %RegistrationPeriod{start_date: future}
      assert RegistrationPeriod.status(rp) == :upcoming
    end

    test "returns :open when only end_date set and today is before it" do
      future = Date.add(Date.utc_today(), 5)
      rp = %RegistrationPeriod{end_date: future}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :closed when only end_date set and today is past it" do
      past = Date.add(Date.utc_today(), -5)
      rp = %RegistrationPeriod{end_date: past}
      assert RegistrationPeriod.status(rp) == :closed
    end
  end

  describe "open?/1" do
    test "true for always_open" do
      assert RegistrationPeriod.open?(%RegistrationPeriod{})
    end

    test "true for open" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: Date.add(today, -5), end_date: Date.add(today, 5)}
      assert RegistrationPeriod.open?(rp)
    end

    test "false for upcoming" do
      future = Date.add(Date.utc_today(), 30)
      rp = %RegistrationPeriod{start_date: future}
      refute RegistrationPeriod.open?(rp)
    end

    test "false for closed" do
      past = Date.add(Date.utc_today(), -30)
      rp = %RegistrationPeriod{end_date: past}
      refute RegistrationPeriod.open?(rp)
    end
  end
end
