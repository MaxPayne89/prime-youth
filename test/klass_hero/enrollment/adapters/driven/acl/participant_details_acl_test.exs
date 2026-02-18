defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ParticipantDetailsACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.ACL.ParticipantDetailsACL

  describe "get_participant_details/1" do
    test "returns participant details map for an existing child" do
      child =
        insert(:child_schema,
          date_of_birth: ~D[2018-06-15],
          gender: "female",
          school_grade: 3
        )

      assert {:ok, details} = ParticipantDetailsACL.get_participant_details(child.id)
      assert details.date_of_birth == ~D[2018-06-15]
      assert details.gender == "female"
      assert details.school_grade == 3
    end

    test "returns participant details with nil school_grade" do
      child = insert(:child_schema, school_grade: nil)

      assert {:ok, details} = ParticipantDetailsACL.get_participant_details(child.id)
      assert details.date_of_birth == child.date_of_birth
      assert details.gender == child.gender
      assert is_nil(details.school_grade)
    end

    test "returns error when child does not exist" do
      assert {:error, :not_found} =
               ParticipantDetailsACL.get_participant_details(Ecto.UUID.generate())
    end
  end
end
