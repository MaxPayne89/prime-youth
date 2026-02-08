defmodule KlassHero.IdentityTest do
  @moduledoc """
  Integration tests for the Identity context public API.

  Tests the complete flow from context facade through use cases to repositories.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.AccountsFixtures
  alias KlassHero.Identity
  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Identity.Domain.Models.Child
  alias KlassHero.Identity.Domain.Models.ParentProfile
  alias KlassHero.Identity.Domain.Models.ProviderProfile
  alias KlassHero.Identity.Domain.Models.VerificationDocument
  alias KlassHero.IdentityFixtures
  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter

  # ============================================================================
  # Parent Profile Functions
  # ============================================================================

  describe "create_parent_profile/1" do
    test "creates parent profile through public API" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: "John Doe"
      }

      assert {:ok, %ParentProfile{} = profile} = Identity.create_parent_profile(attrs)
      assert profile.identity_id == attrs.identity_id
      assert profile.display_name == "John Doe"
    end

    test "returns validation error for invalid attrs" do
      attrs = %{identity_id: ""}

      assert {:error, {:validation_error, errors}} = Identity.create_parent_profile(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns duplicate error when profile exists" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id}

      assert {:ok, _} = Identity.create_parent_profile(attrs)
      assert {:error, :duplicate_resource} = Identity.create_parent_profile(attrs)
    end
  end

  describe "get_parent_by_identity/1" do
    test "retrieves existing parent profile" do
      identity_id = Ecto.UUID.generate()
      {:ok, created} = Identity.create_parent_profile(%{identity_id: identity_id})

      assert {:ok, %ParentProfile{} = retrieved} = Identity.get_parent_by_identity(identity_id)
      assert retrieved.id == created.id
    end

    test "returns not_found for non-existent profile" do
      assert {:error, :not_found} = Identity.get_parent_by_identity(Ecto.UUID.generate())
    end
  end

  describe "has_parent_profile?/1" do
    test "returns true when profile exists" do
      identity_id = Ecto.UUID.generate()
      {:ok, _} = Identity.create_parent_profile(%{identity_id: identity_id})

      assert Identity.has_parent_profile?(identity_id) == true
    end

    test "returns false when profile does not exist" do
      assert Identity.has_parent_profile?(Ecto.UUID.generate()) == false
    end
  end

  # ============================================================================
  # Provider Profile Functions
  # ============================================================================

  describe "create_provider_profile/1" do
    test "creates provider profile through public API" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Kids Sports Academy"
      }

      assert {:ok, %ProviderProfile{} = profile} = Identity.create_provider_profile(attrs)
      assert profile.identity_id == attrs.identity_id
      assert profile.business_name == "Kids Sports Academy"
    end

    test "returns validation error for invalid attrs" do
      attrs = %{identity_id: Ecto.UUID.generate(), business_name: ""}

      assert {:error, {:validation_error, errors}} = Identity.create_provider_profile(attrs)
      assert "Business name cannot be empty" in errors
    end

    test "returns duplicate error when profile exists" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, business_name: "My Business"}

      assert {:ok, _} = Identity.create_provider_profile(attrs)
      assert {:error, :duplicate_resource} = Identity.create_provider_profile(attrs)
    end
  end

  describe "get_provider_by_identity/1" do
    test "retrieves existing provider profile" do
      identity_id = Ecto.UUID.generate()

      {:ok, created} =
        Identity.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "My Business"
        })

      assert {:ok, %ProviderProfile{} = retrieved} =
               Identity.get_provider_by_identity(identity_id)

      assert retrieved.id == created.id
    end

    test "returns not_found for non-existent profile" do
      assert {:error, :not_found} = Identity.get_provider_by_identity(Ecto.UUID.generate())
    end
  end

  describe "has_provider_profile?/1" do
    test "returns true when profile exists" do
      identity_id = Ecto.UUID.generate()

      {:ok, _} =
        Identity.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "My Business"
        })

      assert Identity.has_provider_profile?(identity_id) == true
    end

    test "returns false when profile does not exist" do
      assert Identity.has_provider_profile?(Ecto.UUID.generate()) == false
    end
  end

  # ============================================================================
  # Children Functions
  # ============================================================================

  defp create_parent_for_children do
    identity_id = Ecto.UUID.generate()
    {:ok, parent} = Identity.create_parent_profile(%{identity_id: identity_id})
    parent
  end

  describe "get_children/1" do
    test "returns children for parent" do
      alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository

      parent = create_parent_for_children()

      {:ok, _} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      children = Identity.get_children(parent.id)

      assert length(children) == 1
      assert Enum.at(children, 0).first_name == "Emma"
    end

    test "returns empty list when no children" do
      parent = create_parent_for_children()
      children = Identity.get_children(parent.id)

      assert children == []
    end
  end

  describe "change_child/0" do
    test "returns a valid changeset for empty attrs" do
      changeset = Identity.change_child()
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "change_child/1 with attrs" do
    test "returns changeset with provided values" do
      changeset = Identity.change_child(%{"first_name" => "Emma", "last_name" => "Smith"})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_field(changeset, :first_name) == "Emma"
      assert Ecto.Changeset.get_field(changeset, :last_name) == "Smith"
    end
  end

  describe "change_child/2 with Child struct" do
    test "returns changeset pre-filled from domain struct" do
      child = %Child{
        id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        emergency_contact: nil,
        support_needs: nil,
        allergies: nil
      }

      changeset = Identity.change_child(child, %{})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_field(changeset, :first_name) == "Emma"
      assert Ecto.Changeset.get_field(changeset, :last_name) == "Smith"
      assert Ecto.Changeset.get_field(changeset, :date_of_birth) == ~D[2015-06-15]
    end

    test "returns changeset with updated attrs from domain struct" do
      child = %Child{
        id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        emergency_contact: nil,
        support_needs: nil,
        allergies: nil
      }

      changeset = Identity.change_child(child, %{"first_name" => "Updated"})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_field(changeset, :first_name) == "Updated"
      assert Ecto.Changeset.get_field(changeset, :last_name) == "Smith"
    end
  end

  describe "get_child_by_id/1" do
    test "retrieves existing child" do
      alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository

      parent = create_parent_for_children()

      {:ok, created} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert {:ok, %Child{} = retrieved} = Identity.get_child_by_id(created.id)
      assert retrieved.id == created.id
      assert retrieved.first_name == "Emma"
    end

    test "returns not_found for non-existent child" do
      assert {:error, :not_found} = Identity.get_child_by_id(Ecto.UUID.generate())
    end
  end

  # ============================================================================
  # Verification Document Functions
  # ============================================================================

  describe "submit_verification_document/1" do
    setup do
      name = :"stub_storage_#{System.unique_integer([:positive])}"
      {:ok, storage} = StubStorageAdapter.start_link(name: name)
      provider = IdentityFixtures.provider_profile_fixture()
      %{provider: provider, storage: storage}
    end

    test "delegates to SubmitVerificationDocument use case", %{
      provider: provider,
      storage: storage
    } do
      params = %{
        provider_profile_id: provider.id,
        document_type: "business_registration",
        file_binary: "content",
        original_filename: "doc.pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:ok, %VerificationDocument{} = doc} = Identity.submit_verification_document(params)
      assert doc.provider_profile_id == provider.id
      assert doc.status == :pending
    end
  end

  describe "approve_verification_document/2" do
    setup do
      provider = IdentityFixtures.provider_profile_fixture()
      admin = AccountsFixtures.user_fixture(%{is_admin: true})
      {:ok, doc} = create_pending_document(provider.id)
      %{provider: provider, admin: admin, document: doc}
    end

    test "delegates with correct arg mapping", %{admin: admin, document: doc} do
      assert {:ok, %VerificationDocument{} = approved} =
               Identity.approve_verification_document(doc.id, admin.id)

      assert approved.status == :approved
      assert approved.reviewed_by_id == admin.id
    end
  end

  describe "reject_verification_document/3" do
    setup do
      provider = IdentityFixtures.provider_profile_fixture()
      admin = AccountsFixtures.user_fixture(%{is_admin: true})
      {:ok, doc} = create_pending_document(provider.id)
      %{provider: provider, admin: admin, document: doc}
    end

    test "delegates with correct arg mapping", %{admin: admin, document: doc} do
      assert {:ok, %VerificationDocument{} = rejected} =
               Identity.reject_verification_document(doc.id, admin.id, "Expired document")

      assert rejected.status == :rejected
      assert rejected.rejection_reason == "Expired document"
    end
  end

  describe "get_provider_verification_documents/1" do
    setup do
      provider = IdentityFixtures.provider_profile_fixture()
      {:ok, doc} = create_pending_document(provider.id)
      %{provider: provider, document: doc}
    end

    test "returns documents for provider", %{provider: provider, document: doc} do
      assert {:ok, docs} = Identity.get_provider_verification_documents(provider.id)
      assert length(docs) == 1
      assert Enum.at(docs, 0).id == doc.id
    end

    test "returns empty list for provider with no documents" do
      other_provider = IdentityFixtures.provider_profile_fixture()
      assert {:ok, []} = Identity.get_provider_verification_documents(other_provider.id)
    end
  end

  describe "list_pending_verification_documents/0" do
    setup do
      provider = IdentityFixtures.provider_profile_fixture()
      {:ok, doc} = create_pending_document(provider.id)
      %{provider: provider, document: doc}
    end

    test "returns pending documents", %{document: doc} do
      assert {:ok, docs} = Identity.list_pending_verification_documents()
      assert Enum.any?(docs, fn d -> d.id == doc.id end)
    end
  end

  # ============================================================================
  # Admin Verification Review Functions
  # ============================================================================

  describe "list_verification_documents_for_admin/1" do
    setup do
      provider = IdentityFixtures.provider_profile_fixture(%{business_name: "Admin Test Corp"})
      {:ok, pending} = create_pending_document(provider.id)

      admin = AccountsFixtures.user_fixture(%{is_admin: true})
      {:ok, approved} = create_and_approve_document(provider.id, admin.id)

      %{provider: provider, pending: pending, approved: approved}
    end

    test "returns all documents with provider business names when status is nil", %{
      pending: pending,
      approved: approved
    } do
      assert {:ok, results} = Identity.list_verification_documents_for_admin(nil)

      ids = Enum.map(results, fn %{document: d} -> d.id end)
      assert pending.id in ids
      assert approved.id in ids

      # Verify the result shape includes provider business name
      result = Enum.find(results, fn %{document: d} -> d.id == pending.id end)
      assert result.provider_business_name == "Admin Test Corp"
    end

    test "filters by pending status", %{pending: pending, approved: approved} do
      assert {:ok, results} = Identity.list_verification_documents_for_admin(:pending)

      ids = Enum.map(results, fn %{document: d} -> d.id end)
      assert pending.id in ids
      refute approved.id in ids
    end

    test "filters by approved status", %{pending: pending, approved: approved} do
      assert {:ok, results} = Identity.list_verification_documents_for_admin(:approved)

      ids = Enum.map(results, fn %{document: d} -> d.id end)
      refute pending.id in ids
      assert approved.id in ids
    end

    test "returns empty list when no documents match" do
      assert {:ok, []} = Identity.list_verification_documents_for_admin(:rejected)
    end

    test "pending documents are ordered oldest first (FIFO)" do
      provider = IdentityFixtures.provider_profile_fixture()
      {:ok, first} = create_pending_document(provider.id)

      # Small delay to ensure different timestamps
      {:ok, second} = create_pending_document(provider.id)

      assert {:ok, results} = Identity.list_verification_documents_for_admin(:pending)
      pending_ids = Enum.map(results, fn %{document: d} -> d.id end)

      first_idx = Enum.find_index(pending_ids, &(&1 == first.id))
      second_idx = Enum.find_index(pending_ids, &(&1 == second.id))
      assert first_idx < second_idx
    end
  end

  describe "get_verification_document_for_admin/1" do
    setup do
      provider = IdentityFixtures.provider_profile_fixture(%{business_name: "Review Corp"})
      {:ok, doc} = create_pending_document(provider.id)
      %{provider: provider, document: doc}
    end

    test "returns document with provider business name", %{document: doc} do
      assert {:ok, result} = Identity.get_verification_document_for_admin(doc.id)
      assert result.document.id == doc.id
      assert result.provider_business_name == "Review Corp"
    end

    test "returns {:error, :not_found} for nonexistent ID" do
      assert {:error, :not_found} =
               Identity.get_verification_document_for_admin(Ecto.UUID.generate())
    end
  end

  # ============================================================================
  # Provider Verification Functions
  # ============================================================================

  describe "verify_provider/2" do
    setup do
      setup_test_integration_events()
      provider = IdentityFixtures.provider_profile_fixture()
      admin = AccountsFixtures.user_fixture(%{is_admin: true})
      %{provider: provider, admin: admin}
    end

    test "delegates with correct arg mapping", %{provider: provider, admin: admin} do
      assert {:ok, %ProviderProfile{} = verified} =
               Identity.verify_provider(provider.id, admin.id)

      assert verified.verified == true
      assert verified.verified_at != nil
    end
  end

  describe "unverify_provider/2" do
    setup do
      setup_test_integration_events()
      provider = IdentityFixtures.provider_profile_fixture()
      admin = AccountsFixtures.user_fixture(%{is_admin: true})
      # First verify the provider so we can unverify
      {:ok, _} = Identity.verify_provider(provider.id, admin.id)
      %{provider: provider, admin: admin}
    end

    test "delegates with correct arg mapping", %{provider: provider, admin: admin} do
      assert {:ok, %ProviderProfile{} = unverified} =
               Identity.unverify_provider(provider.id, admin.id)

      assert unverified.verified == false
      assert unverified.verified_at == nil
    end
  end

  describe "list_verified_provider_ids/0" do
    test "returns verified provider IDs" do
      setup_test_integration_events()
      provider = IdentityFixtures.provider_profile_fixture()
      admin = AccountsFixtures.user_fixture(%{is_admin: true})

      {:ok, _} = Identity.verify_provider(provider.id, admin.id)

      assert {:ok, ids} = Identity.list_verified_provider_ids()
      assert provider.id in ids
    end
  end

  # ============================================================================
  # Test Helpers
  # ============================================================================

  defp create_pending_document(provider_id) do
    {:ok, doc} =
      VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: provider_id,
        document_type: "business_registration",
        file_url: "verification-docs/test.pdf",
        original_filename: "doc.pdf"
      })

    VerificationDocumentRepository.create(doc)
  end

  defp create_and_approve_document(provider_id, admin_id) do
    {:ok, doc} = create_pending_document(provider_id)
    Identity.approve_verification_document(doc.id, admin_id)
  end
end
