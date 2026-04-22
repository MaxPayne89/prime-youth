defmodule KlassHeroWeb.Presenters.StaffMemberPresenterTest do
  @moduledoc """
  Security-critical tests — the base `to_card_view/1` is consumed by the parent-facing
  program detail page. Pay rates MUST NEVER leak through that function. Admin and
  self-view variants may include the rate because they are gated to business owners
  and the staff member themselves.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Models.{PayRate, StaffMember}
  alias KlassHeroWeb.Presenters.StaffMemberPresenter

  defp staff_fixture(overrides) do
    struct!(
      StaffMember,
      Map.merge(
        %{
          id: Ecto.UUID.generate(),
          provider_id: Ecto.UUID.generate(),
          first_name: "Mike",
          last_name: "Johnson",
          role: "Head Coach",
          email: "mike@example.com",
          bio: "Experienced coach.",
          tags: [],
          qualifications: [],
          active: true,
          invitation_status: :accepted
        },
        overrides
      )
    )
  end

  defp hourly_rate do
    {:ok, rate} = PayRate.hourly(Decimal.new("25.00"))
    rate
  end

  describe "to_card_view/1 — parent/public-facing (no pay_rate)" do
    test "never includes pay_rate, even when the StaffMember has one set" do
      staff = staff_fixture(%{pay_rate: hourly_rate()})

      view = StaffMemberPresenter.to_card_view(staff)

      refute Map.has_key?(view, :pay_rate)
      refute Map.has_key?(view, :rate_label)
    end

    test "renders a leak-free view when the StaffMember has no pay_rate" do
      staff = staff_fixture(%{pay_rate: nil})

      view = StaffMemberPresenter.to_card_view(staff)

      refute Map.has_key?(view, :pay_rate)
      assert view.full_name == "Mike Johnson"
    end
  end

  describe "to_card_view_list/1" do
    test "maps a list without leaking pay_rate" do
      list = [staff_fixture(%{pay_rate: hourly_rate()}), staff_fixture(%{pay_rate: nil})]

      views = StaffMemberPresenter.to_card_view_list(list)

      for view <- views do
        refute Map.has_key?(view, :pay_rate)
      end
    end
  end

  describe "to_admin_view/1 — business-owner-facing (includes pay_rate)" do
    test "includes a formatted rate_label when pay_rate is hourly" do
      staff = staff_fixture(%{pay_rate: hourly_rate()})

      view = StaffMemberPresenter.to_admin_view(staff)

      assert view.pay_rate.type == :hourly
      assert view.rate_label == "€25.00 / hour"
    end

    test "includes a formatted rate_label when pay_rate is per_session" do
      {:ok, rate} = PayRate.per_session(Decimal.new("80.00"))
      staff = staff_fixture(%{pay_rate: rate})

      view = StaffMemberPresenter.to_admin_view(staff)

      assert view.rate_label == "€80.00 / session"
    end

    test "returns nil rate_label when pay_rate is nil" do
      staff = staff_fixture(%{pay_rate: nil})

      view = StaffMemberPresenter.to_admin_view(staff)

      assert is_nil(view.pay_rate)
      assert is_nil(view.rate_label)
    end
  end

  describe "to_self_view/1 — staff-member-facing (includes own pay_rate)" do
    test "includes the staff's own pay rate" do
      staff = staff_fixture(%{pay_rate: hourly_rate()})

      view = StaffMemberPresenter.to_self_view(staff)

      assert view.pay_rate.type == :hourly
      assert view.rate_label == "€25.00 / hour"
    end

    test "returns nil rate_label when no pay_rate is set" do
      staff = staff_fixture(%{pay_rate: nil})

      view = StaffMemberPresenter.to_self_view(staff)

      assert is_nil(view.pay_rate)
      assert is_nil(view.rate_label)
    end
  end
end
