defmodule KlassHero.Messaging.Application.UseCases.CreateDirectConversationTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Accounts.Scope
  alias KlassHero.AccountsFixtures
  alias KlassHero.Family.Domain.Models.ParentProfile
  alias KlassHero.Messaging.Application.UseCases.CreateDirectConversation
  alias KlassHero.Messaging.Domain.Models.Conversation
  alias KlassHero.Provider.Domain.Models.ProviderProfile

  describe "execute/3" do
    test "creates new conversation with participants" do
      provider = insert(:provider_profile_schema)
      scope = build_scope_with_provider(provider, :professional)

      target_user = AccountsFixtures.user_fixture()

      assert {:ok, conversation} =
               CreateDirectConversation.execute(scope, provider.id, target_user.id)

      assert %Conversation{} = conversation
      assert conversation.type == :direct
      assert conversation.provider_id == provider.id
    end

    test "returns existing conversation if one already exists" do
      provider = insert(:provider_profile_schema)
      scope = build_scope_with_provider(provider, :professional)

      target_user = AccountsFixtures.user_fixture()

      assert {:ok, first_conversation} =
               CreateDirectConversation.execute(scope, provider.id, target_user.id)

      assert {:ok, second_conversation} =
               CreateDirectConversation.execute(scope, provider.id, target_user.id)

      assert first_conversation.id == second_conversation.id
    end

    test "returns not_entitled error for free-tier parent" do
      provider = insert(:provider_profile_schema)
      scope = build_scope_with_parent(:explorer)

      target_user = AccountsFixtures.user_fixture()

      assert {:error, :not_entitled} =
               CreateDirectConversation.execute(scope, provider.id, target_user.id)
    end

    test "provider with professional tier can initiate" do
      provider = insert(:provider_profile_schema)
      scope = build_scope_with_provider(provider, :professional)

      target_user = AccountsFixtures.user_fixture()

      assert {:ok, _conversation} =
               CreateDirectConversation.execute(scope, provider.id, target_user.id)
    end

    test "provider with business_plus tier can initiate" do
      provider = insert(:provider_profile_schema)
      scope = build_scope_with_provider(provider, :business_plus)

      target_user = AccountsFixtures.user_fixture()

      assert {:ok, _conversation} =
               CreateDirectConversation.execute(scope, provider.id, target_user.id)
    end

    test "parent with active tier can initiate" do
      provider = insert(:provider_profile_schema)
      scope = build_scope_with_parent(:active)

      target_user = AccountsFixtures.user_fixture()

      assert {:ok, _conversation} =
               CreateDirectConversation.execute(scope, provider.id, target_user.id)
    end
  end

  defp build_scope_with_provider(provider_schema, tier) do
    user = AccountsFixtures.user_fixture()

    provider_profile = %ProviderProfile{
      id: provider_schema.id,
      identity_id: user.id,
      business_name: "Test Provider",
      subscription_tier: tier
    }

    %Scope{
      user: user,
      roles: [:provider],
      provider: provider_profile,
      parent: nil
    }
  end

  defp build_scope_with_parent(tier) do
    user = AccountsFixtures.user_fixture()

    parent_profile = %ParentProfile{
      id: Ecto.UUID.generate(),
      identity_id: user.id,
      display_name: "Test Parent",
      subscription_tier: tier
    }

    %Scope{
      user: user,
      roles: [:parent],
      parent: parent_profile,
      provider: nil
    }
  end
end
