defmodule KlassHeroWeb.Presenters.ProviderPresenterTest do
  use ExUnit.Case, async: true

  alias KlassHeroWeb.Presenters.ProviderPresenter

  describe "verification_status_from_docs/2" do
    test "returns :verified when provider.verified is true and no docs" do
      assert ProviderPresenter.verification_status_from_docs(true, []) == :verified
    end

    test "returns :verified even when docs are pending" do
      docs = [%{status: :pending}]
      assert ProviderPresenter.verification_status_from_docs(true, docs) == :verified
    end

    test "returns :not_started when no docs submitted" do
      assert ProviderPresenter.verification_status_from_docs(false, []) == :not_started
    end

    test "returns :not_started when verified is nil" do
      assert ProviderPresenter.verification_status_from_docs(nil, []) == :not_started
    end

    test "returns :pending when any doc is pending" do
      docs = [%{status: :pending}]
      assert ProviderPresenter.verification_status_from_docs(false, docs) == :pending
    end

    test "returns :rejected when any doc is rejected" do
      docs = [%{status: :rejected}]
      assert ProviderPresenter.verification_status_from_docs(false, docs) == :rejected
    end

    test "returns :pending when all docs approved (awaiting admin final verification)" do
      docs = [%{status: :approved}]
      assert ProviderPresenter.verification_status_from_docs(false, docs) == :pending
    end

    test "pending takes priority over rejected" do
      docs = [%{status: :pending}, %{status: :rejected}]
      assert ProviderPresenter.verification_status_from_docs(false, docs) == :pending
    end

    test "rejected present among approved" do
      docs = [%{status: :approved}, %{status: :rejected}]
      assert ProviderPresenter.verification_status_from_docs(false, docs) == :rejected
    end
  end

  describe "to_business_view/1" do
    alias KlassHero.Provider.Domain.Models.ProviderProfile

    test "includes team seat fields for starter tier" do
      provider = %ProviderProfile{
        id: "p1",
        identity_id: "i1",
        business_name: "Test Biz",
        subscription_tier: :starter
      }

      view = ProviderPresenter.to_business_view(provider)

      assert view.team_seats_used == 0
      assert view.team_seats_total == 1
    end

    test "includes unlimited team seats for business_plus tier" do
      provider = %ProviderProfile{
        id: "p2",
        identity_id: "i2",
        business_name: "Big Biz",
        subscription_tier: :business_plus
      }

      view = ProviderPresenter.to_business_view(provider)

      assert view.team_seats_used == 0
      assert view.team_seats_total == :unlimited
    end
  end

  describe "tier_label/1" do
    test "returns label for each valid tier" do
      assert ProviderPresenter.tier_label(:starter) == "Starter Plan"
      assert ProviderPresenter.tier_label(:professional) == "Professional Plan"
      assert ProviderPresenter.tier_label(:business_plus) == "Business Plus Plan"
    end

    test "raises FunctionClauseError for unknown tier" do
      assert_raise FunctionClauseError, fn ->
        ProviderPresenter.tier_label(:unknown)
      end
    end
  end
end
