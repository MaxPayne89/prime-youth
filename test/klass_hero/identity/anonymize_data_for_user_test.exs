defmodule KlassHero.Identity.AnonymizeDataForUserTest do
  @moduledoc """
  Tests for Identity.anonymize_data_for_user/1.

  Verifies GDPR account anonymization cascades to children and consents
  in the Identity context, and publishes events for downstream contexts.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper
  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Identity
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ConsentSchema

  describe "anonymize_data_for_user/1" do
    setup do
      setup_test_events()
      :ok
    end

    test "anonymizes child PII fields" do
      user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: user.id)

      child =
        insert(:child_schema,
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          emergency_contact: "+49123456",
          support_needs: "Wheelchair access",
          allergies: "Peanuts"
        )

      {:ok, _summary} = Identity.anonymize_data_for_user(user.id)

      reloaded = Repo.get!(ChildSchema, child.id)
      assert reloaded.first_name == "Anonymized"
      assert reloaded.last_name == "Child"
      assert is_nil(reloaded.emergency_contact)
      assert is_nil(reloaded.support_needs)
      assert is_nil(reloaded.allergies)
    end

    test "anonymizes date_of_birth and preserves parent_id after anonymization" do
      user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: user.id)

      child =
        insert(:child_schema,
          parent_id: parent.id,
          date_of_birth: ~D[2018-03-15]
        )

      {:ok, _summary} = Identity.anonymize_data_for_user(user.id)

      reloaded = Repo.get!(ChildSchema, child.id)
      assert is_nil(reloaded.date_of_birth)
      assert reloaded.parent_id == parent.id
    end

    test "deletes all consents for each child" do
      user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: user.id)
      child = insert(:child_schema, parent_id: parent.id)

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "photo",
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      # Verify consents exist before
      assert Repo.aggregate(
               from(c in ConsentSchema, where: c.child_id == ^child.id),
               :count
             ) == 2

      {:ok, summary} = Identity.anonymize_data_for_user(user.id)

      assert summary.consents_deleted == 2

      assert Repo.aggregate(
               from(c in ConsentSchema, where: c.child_id == ^child.id),
               :count
             ) == 0
    end

    test "publishes child_data_anonymized event per child" do
      user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: user.id)
      child = insert(:child_schema, parent_id: parent.id)

      {:ok, _summary} = Identity.anonymize_data_for_user(user.id)

      event = assert_event_published(:child_data_anonymized)
      assert event.aggregate_id == child.id
      assert event.payload.child_id == child.id
    end

    test "handles multiple children — all anonymized with consents deleted and events published" do
      user = AccountsFixtures.user_fixture()
      parent = insert(:parent_profile_schema, identity_id: user.id)

      child_a = insert(:child_schema, parent_id: parent.id, first_name: "Alice")
      child_b = insert(:child_schema, parent_id: parent.id, first_name: "Bob")

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child_a.id,
        consent_type: "provider_data_sharing"
      )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child_b.id,
        consent_type: "photo"
      )

      {:ok, summary} = Identity.anonymize_data_for_user(user.id)

      assert summary.children_anonymized == 2
      assert summary.consents_deleted == 2

      reloaded_a = Repo.get!(ChildSchema, child_a.id)
      reloaded_b = Repo.get!(ChildSchema, child_b.id)

      assert reloaded_a.first_name == "Anonymized"
      assert reloaded_b.first_name == "Anonymized"

      # Verify one child_data_anonymized event per child
      events = get_published_events()

      child_events =
        Enum.filter(events, &(&1.event_type == :child_data_anonymized))

      assert length(child_events) == 2

      event_child_ids = MapSet.new(child_events, & &1.aggregate_id)
      assert MapSet.member?(event_child_ids, child_a.id)
      assert MapSet.member?(event_child_ids, child_b.id)
    end

    test "returns :no_data for user without parent profile" do
      user = AccountsFixtures.user_fixture()

      assert {:ok, :no_data} = Identity.anonymize_data_for_user(user.id)
    end
  end
end
