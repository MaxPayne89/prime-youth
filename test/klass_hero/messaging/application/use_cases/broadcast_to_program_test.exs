defmodule KlassHero.Messaging.Application.UseCases.BroadcastToProgramTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Accounts.Scope
  alias KlassHero.AccountsFixtures
  alias KlassHero.Identity.Domain.Models.ProviderProfile
  alias KlassHero.Messaging.Application.UseCases.BroadcastToProgram
  alias KlassHero.Messaging.Domain.Models.{Conversation, Message}

  describe "execute/4" do
    test "creates broadcast conversation and message with enrolled parents" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)
      scope = build_scope_with_provider(provider, :professional)

      # Create parents with real users to satisfy FK constraint
      parent_user1 = AccountsFixtures.user_fixture()
      parent_user2 = AccountsFixtures.user_fixture()
      parent1 = insert(:parent_profile_schema, identity_id: parent_user1.id)
      parent2 = insert(:parent_profile_schema, identity_id: parent_user2.id)

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent1.id,
        status: "confirmed"
      )

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent2.id,
        status: "pending"
      )

      assert {:ok, conversation, message, recipient_count} =
               BroadcastToProgram.execute(scope, program.id, "Important announcement!")

      assert %Conversation{} = conversation
      assert conversation.type == :program_broadcast
      assert conversation.program_id == program.id

      assert %Message{} = message
      assert message.content == "Important announcement!"

      assert recipient_count == 2
    end

    test "includes subject when provided" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)
      scope = build_scope_with_provider(provider, :professional)

      parent_user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: parent_user.id)

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      assert {:ok, conversation, _message, _count} =
               BroadcastToProgram.execute(
                 scope,
                 program.id,
                 "Content",
                 subject: "Schedule Change"
               )

      assert conversation.subject == "Schedule Change"
    end

    test "returns not_entitled error for starter tier provider" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)
      scope = build_scope_with_provider(provider, :starter)

      parent = insert(:parent_profile_schema)

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      assert {:error, :not_entitled} =
               BroadcastToProgram.execute(scope, program.id, "Message")
    end

    test "returns no_enrollments error when no parents enrolled" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)
      scope = build_scope_with_provider(provider, :professional)

      assert {:error, :no_enrollments} =
               BroadcastToProgram.execute(scope, program.id, "Message")
    end

    test "excludes cancelled and completed enrollments" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)
      scope = build_scope_with_provider(provider, :professional)

      active_user = AccountsFixtures.user_fixture()
      cancelled_user = AccountsFixtures.user_fixture()
      completed_user = AccountsFixtures.user_fixture()
      active_parent = insert(:parent_profile_schema, identity_id: active_user.id)
      cancelled_parent = insert(:parent_profile_schema, identity_id: cancelled_user.id)
      completed_parent = insert(:parent_profile_schema, identity_id: completed_user.id)

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: active_parent.id,
        status: "confirmed"
      )

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: cancelled_parent.id,
        status: "cancelled"
      )

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: completed_parent.id,
        status: "completed"
      )

      assert {:ok, _conversation, _message, recipient_count} =
               BroadcastToProgram.execute(scope, program.id, "Message")

      assert recipient_count == 1
    end

    test "professional tier provider can broadcast" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)
      scope = build_scope_with_provider(provider, :professional)

      parent_user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: parent_user.id)

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      assert {:ok, _conversation, _message, _count} =
               BroadcastToProgram.execute(scope, program.id, "Message")
    end

    test "business_plus tier provider can broadcast" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)
      scope = build_scope_with_provider(provider, :business_plus)

      parent_user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: parent_user.id)

      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      assert {:ok, _conversation, _message, _count} =
               BroadcastToProgram.execute(scope, program.id, "Message")
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
end
