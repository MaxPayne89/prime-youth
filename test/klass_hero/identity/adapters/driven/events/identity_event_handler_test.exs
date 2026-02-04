defmodule KlassHero.Identity.Adapters.Driven.Events.IdentityEventHandlerTest do
  @moduledoc """
  Tests for IdentityEventHandler handling of user_anonymized events.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper
  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Identity.Adapters.Driven.Events.IdentityEventHandler
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ConsentSchema
  alias KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents

  describe "handle_event/1 for :user_anonymized" do
    setup do
      setup_test_integration_events()
      :ok
    end

    test "anonymizes children and deletes consents for the user" do
      user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: user.id)

      child =
        insert(:child_schema,
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          emergency_contact: "+49123",
          support_needs: "Extra help",
          allergies: "Nuts"
        )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      )

      event =
        AccountsIntegrationEvents.user_anonymized(
          user.id,
          %{anonymized_email: "deleted_#{user.id}@anonymized.local"}
        )

      assert :ok == IdentityEventHandler.handle_event(event)

      reloaded = Repo.get!(ChildSchema, child.id)
      assert reloaded.first_name == "Anonymized"
      assert reloaded.last_name == "Child"
      assert is_nil(reloaded.emergency_contact)
      assert is_nil(reloaded.support_needs)
      assert is_nil(reloaded.allergies)

      assert Repo.aggregate(
               from(c in ConsentSchema, where: c.child_id == ^child.id),
               :count
             ) == 0
    end

    test "publishes child_data_anonymized event per child" do
      user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: user.id)
      child = insert(:child_schema, parent_id: parent.id)

      event =
        AccountsIntegrationEvents.user_anonymized(
          user.id,
          %{anonymized_email: "deleted_#{user.id}@anonymized.local"}
        )

      assert :ok == IdentityEventHandler.handle_event(event)

      child_event = assert_integration_event_published(:child_data_anonymized)
      assert child_event.entity_id == child.id
    end

    test "returns :ok for user without parent profile" do
      user = AccountsFixtures.user_fixture()

      event =
        AccountsIntegrationEvents.user_anonymized(
          user.id,
          %{anonymized_email: "deleted_#{user.id}@anonymized.local"}
        )

      assert :ok == IdentityEventHandler.handle_event(event)
    end
  end

  describe "subscribed_events/0" do
    test "includes :user_anonymized" do
      assert :user_anonymized in IdentityEventHandler.subscribed_events()
    end

    test "includes :user_registered" do
      assert :user_registered in IdentityEventHandler.subscribed_events()
    end
  end
end
