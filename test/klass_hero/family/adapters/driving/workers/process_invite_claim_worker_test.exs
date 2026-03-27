defmodule KlassHero.Family.Adapters.Driving.Workers.ProcessInviteClaimWorkerTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Family
  alias KlassHero.Family.Adapters.Driving.Workers.ProcessInviteClaimWorker

  describe "perform/1" do
    test "processes invite claim and creates parent + child" do
      user = user_fixture()

      job =
        ProcessInviteClaimWorker.new(%{
          "invite_id" => Ecto.UUID.generate(),
          "user_id" => user.id,
          "program_id" => Ecto.UUID.generate(),
          "child_first_name" => "Emma",
          "child_last_name" => "Schmidt",
          "child_date_of_birth" => "2016-03-15",
          "school_grade" => 3,
          "school_name" => "Berlin Elementary",
          "medical_conditions" => "Asthma",
          "nut_allergy" => true
        })
        |> Oban.insert!()

      assert :ok = ProcessInviteClaimWorker.perform(job)

      {:ok, parent} = Family.get_parent_by_identity(user.id)
      children = Family.get_children(parent.id)
      assert length(children) == 1
      assert hd(children).first_name == "Emma"
    end

    test "returns error for malformed date_of_birth string" do
      user = user_fixture()

      job =
        ProcessInviteClaimWorker.new(%{
          "invite_id" => Ecto.UUID.generate(),
          "user_id" => user.id,
          "program_id" => Ecto.UUID.generate(),
          "child_first_name" => "Emma",
          "child_last_name" => "Schmidt",
          "child_date_of_birth" => "not-a-date"
        })
        |> Oban.insert!()

      assert {:error, {:invalid_date, "not-a-date"}} =
               ProcessInviteClaimWorker.perform(job)
    end

    test "handles nil date_of_birth in args" do
      user = user_fixture()

      job =
        ProcessInviteClaimWorker.new(%{
          "invite_id" => Ecto.UUID.generate(),
          "user_id" => user.id,
          "program_id" => Ecto.UUID.generate(),
          "child_first_name" => "Emma",
          "child_last_name" => "Schmidt",
          "child_date_of_birth" => nil
        })
        |> Oban.insert!()

      # Will fail at domain validation (date_of_birth required), but worker should not crash
      result = ProcessInviteClaimWorker.perform(job)
      assert {:error, _reason} = result
    end
  end
end
