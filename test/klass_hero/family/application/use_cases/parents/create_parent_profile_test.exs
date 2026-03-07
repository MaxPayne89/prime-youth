defmodule KlassHero.Family.Application.UseCases.Parents.CreateParentProfileTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Family.Application.UseCases.Parents.CreateParentProfile
  alias KlassHero.Family.Domain.Models.ParentProfile

  describe "execute/1" do
    test "creates parent profile with all fields and returns domain struct" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])

      attrs = %{
        identity_id: user.id,
        display_name: "Jane Parent",
        phone: "+1555123456",
        location: "San Francisco, CA",
        notification_preferences: %{email: true, sms: false}
      }

      assert {:ok, %ParentProfile{} = profile} = CreateParentProfile.execute(attrs)
      assert is_binary(profile.id)
      assert profile.identity_id == user.id
      assert profile.display_name == "Jane Parent"
      assert profile.phone == "+1555123456"
      assert profile.location == "San Francisco, CA"
      assert is_map(profile.notification_preferences)
    end

    test "creates parent profile with minimal attrs (identity_id only)" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])

      assert {:ok, %ParentProfile{} = profile} =
               CreateParentProfile.execute(%{identity_id: user.id})

      assert is_binary(profile.id)
      assert profile.identity_id == user.id
      assert is_nil(profile.display_name)
      assert is_nil(profile.phone)
    end

    test "generates UUID for id when not provided" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])

      {:ok, profile} = CreateParentProfile.execute(%{identity_id: user.id})

      assert is_binary(profile.id)
      assert byte_size(profile.id) == 36
    end

    test "uses caller-provided id when given" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])
      custom_id = Ecto.UUID.generate()

      {:ok, profile} = CreateParentProfile.execute(%{id: custom_id, identity_id: user.id})

      assert profile.id == custom_id
    end

    test "returns validation error for empty identity_id" do
      assert {:error, {:validation_error, errors}} =
               CreateParentProfile.execute(%{identity_id: ""})

      assert is_list(errors)
      assert errors != []
    end

    test "returns validation error for display_name exceeding 100 characters" do
      long_name = String.duplicate("x", 101)

      assert {:error, {:validation_error, errors}} =
               CreateParentProfile.execute(%{
                 identity_id: Ecto.UUID.generate(),
                 display_name: long_name
               })

      assert is_list(errors)
      assert errors != []
    end

    test "returns validation error for phone exceeding 20 characters" do
      long_phone = String.duplicate("1", 21)

      assert {:error, {:validation_error, errors}} =
               CreateParentProfile.execute(%{
                 identity_id: Ecto.UUID.generate(),
                 phone: long_phone
               })

      assert is_list(errors)
      assert errors != []
    end

    test "returns :duplicate_resource when profile already exists for identity_id" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])
      attrs = %{identity_id: user.id, display_name: "First Profile"}

      assert {:ok, _} = CreateParentProfile.execute(attrs)
      assert {:error, :duplicate_resource} = CreateParentProfile.execute(%{identity_id: user.id})
    end
  end
end
