defmodule KlassHero.Accounts.Types.UserRoleStaffProviderTest do
  use ExUnit.Case, async: true

  alias KlassHero.Accounts.Types.UserRole

  test ":staff_provider is a valid role" do
    assert UserRole.valid_role?(:staff_provider)
  end

  test ":staff_provider can be converted to string" do
    assert {:ok, "staff_provider"} = UserRole.to_string(:staff_provider)
  end

  test ":staff_provider can be parsed from string" do
    assert {:ok, :staff_provider} = UserRole.from_string("staff_provider")
  end

  test ":staff_provider has permissions" do
    assert is_list(UserRole.permissions(:staff_provider))
    refute Enum.empty?(UserRole.permissions(:staff_provider))
  end
end
