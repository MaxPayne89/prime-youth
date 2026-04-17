defmodule KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildrenTest do
  use KlassHero.DataCase, async: false

  import Ecto.Query
  import KlassHero.Factory

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EnrolledChildrenSchema
  alias KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren
  alias KlassHero.Repo

  @test_server_name :enrolled_children_projection_test

  setup do
    pid = start_supervised!({EnrolledChildren, name: @test_server_name})
    {:ok, pid: pid}
  end

  describe "bootstrap" do
    test "projects existing enrollments into messaging_enrolled_children on startup" do
      user = user_fixture(name: "Sarah Johnson")
      parent = insert(:parent_profile_schema, identity_id: user.id)
      child = insert(:child_schema, first_name: "Emma", last_name: "Johnson")
      insert(:child_guardian_schema, child_id: child.id, guardian_id: parent.id)
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        program_id: program.id,
        status: "confirmed"
      )

      EnrolledChildren.rebuild(@test_server_name)

      rows =
        from(e in EnrolledChildrenSchema,
          where: e.parent_user_id == ^user.id and e.program_id == ^program.id
        )
        |> Repo.all()

      assert length(rows) == 1
      [row] = rows
      assert row.child_id == child.id
      assert row.child_first_name == "Emma"
    end

    test "ignores cancelled enrollments during bootstrap" do
      user = user_fixture(name: "Bob Smith")
      parent = insert(:parent_profile_schema, identity_id: user.id)
      child = insert(:child_schema, first_name: "Max")
      insert(:child_guardian_schema, child_id: child.id, guardian_id: parent.id)
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        program_id: program.id,
        status: "cancelled"
      )

      EnrolledChildren.rebuild(@test_server_name)

      count =
        from(e in EnrolledChildrenSchema, where: e.parent_user_id == ^user.id)
        |> Repo.aggregate(:count)

      assert count == 0
    end
  end

  # Helper to create users with specific names
  defp user_fixture(attrs) do
    KlassHero.AccountsFixtures.user_fixture(attrs)
  end
end
