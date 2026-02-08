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
end
