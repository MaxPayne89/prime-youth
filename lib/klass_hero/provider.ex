defmodule KlassHero.Provider do
  @moduledoc """
  Public API for the Provider bounded context.

  Manages provider profiles, verification documents, and staff members.
  Split from the former Identity context to give Provider its own
  bounded context with clear domain boundaries.

  ## Usage

      # Provider Profiles
      {:ok, provider} = Provider.create_provider_profile(%{
        identity_id: "user-uuid",
        business_name: "My Business"
      })
      {:ok, provider} = Provider.get_provider_by_identity("user-uuid")
      true = Provider.has_provider_profile?("user-uuid")

      # Staff Members
      {:ok, staff} = Provider.create_staff_member(%{provider_id: "...", ...})
      {:ok, members} = Provider.list_staff_members("provider-uuid")
  """

  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Shared],
    exports: [
      Domain.Models.ProviderProfile,
      Domain.Models.StaffMember,
      Domain.Models.VerificationDocument,
      Adapters.Driven.Persistence.ChangeProviderProfile,
      Adapters.Driven.Persistence.ChangeStaffMember
    ]

  alias KlassHero.Provider.Adapters.Driven.Persistence.ChangeProviderProfile
  alias KlassHero.Provider.Adapters.Driven.Persistence.ChangeStaffMember
  alias KlassHero.Provider.Application.UseCases.Providers.CreateProviderProfile
  alias KlassHero.Provider.Application.UseCases.Providers.UnverifyProvider
  alias KlassHero.Provider.Application.UseCases.Providers.UpdateProviderProfile
  alias KlassHero.Provider.Application.UseCases.Providers.VerifyProvider
  alias KlassHero.Provider.Application.UseCases.StaffMembers.CreateStaffMember
  alias KlassHero.Provider.Application.UseCases.StaffMembers.DeleteStaffMember
  alias KlassHero.Provider.Application.UseCases.StaffMembers.UpdateStaffMember
  alias KlassHero.Provider.Application.UseCases.Verification.ApproveVerificationDocument
  alias KlassHero.Provider.Application.UseCases.Verification.GetVerificationDocumentPreview
  alias KlassHero.Provider.Application.UseCases.Verification.RejectVerificationDocument
  alias KlassHero.Provider.Application.UseCases.Verification.SubmitVerificationDocument
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Provider.Domain.Models.VerificationDocument
  alias KlassHero.Provider.Domain.Ports.ForStoringVerificationDocuments

  @provider_repository Application.compile_env!(:klass_hero, [
                         :provider,
                         :for_storing_provider_profiles
                       ])
  @verification_document_repository Application.compile_env!(:klass_hero, [
                                      :provider,
                                      :for_storing_verification_documents
                                    ])
  @staff_repository Application.compile_env!(:klass_hero, [
                      :provider,
                      :for_storing_staff_members
                    ])

  # ============================================================================
  # Provider Profile Functions
  # ============================================================================

  @doc """
  Creates a new provider profile.

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile created successfully
  - `{:error, :duplicate_identity}` - Provider profile already exists
  - `{:error, {:validation_error, errors}}` - Domain validation failed
  - `{:error, changeset}` - Persistence validation failed
  """
  def create_provider_profile(attrs) when is_map(attrs) do
    CreateProviderProfile.execute(attrs)
  end

  @doc """
  Retrieves a provider profile by identity ID.

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile found
  - `{:error, :not_found}` - No provider profile exists
  """
  def get_provider_by_identity(identity_id) when is_binary(identity_id) do
    @provider_repository.get_by_identity_id(identity_id)
  end

  @doc """
  Checks if a provider profile exists for the given identity ID.
  """
  def has_provider_profile?(identity_id) when is_binary(identity_id) do
    @provider_repository.has_profile?(identity_id)
  end

  @doc """
  Returns a changeset for tracking provider profile form changes.

  Used by LiveView forms for `to_form()` and `phx-change` validation.
  """
  @spec change_provider_profile(ProviderProfile.t(), map()) :: Ecto.Changeset.t()
  def change_provider_profile(%ProviderProfile{} = provider, attrs \\ %{}) do
    ChangeProviderProfile.execute(provider, attrs)
  end

  @doc """
  Updates an existing provider profile.

  Returns:
  - `{:ok, ProviderProfile.t()}` on success
  - `{:error, :not_found}` if provider doesn't exist
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  @spec update_provider_profile(String.t(), map()) ::
          {:ok, ProviderProfile.t()}
          | {:error, :not_found | {:validation_error, list()} | Ecto.Changeset.t()}
  def update_provider_profile(provider_id, attrs) when is_binary(provider_id) and is_map(attrs) do
    UpdateProviderProfile.execute(provider_id, attrs)
  end

  # ============================================================================
  # Verification Documents
  # ============================================================================

  @doc """
  Submit a verification document for a provider.

  Accepts a map with:
  - `:provider_profile_id` - Required provider profile ID
  - `:document_type` - Required document type
  - `:file_binary` - Required binary content of the uploaded file
  - `:original_filename` - Required original filename
  - `:content_type` - Optional MIME type
  - `:storage_opts` - Optional keyword list of additional storage adapter options
  """
  def submit_verification_document(params) do
    SubmitVerificationDocument.execute(params)
  end

  @doc """
  Approve a verification document (admin only).
  """
  def approve_verification_document(document_id, reviewer_id) do
    ApproveVerificationDocument.execute(%{
      document_id: document_id,
      reviewer_id: reviewer_id
    })
  end

  @doc """
  Reject a verification document with reason (admin only).
  """
  def reject_verification_document(document_id, reviewer_id, reason) do
    RejectVerificationDocument.execute(%{
      document_id: document_id,
      reviewer_id: reviewer_id,
      reason: reason
    })
  end

  @doc """
  Get all verification documents for a provider.
  """
  def get_provider_verification_documents(provider_profile_id) do
    @verification_document_repository.get_by_provider(provider_profile_id)
  end

  @doc """
  List all pending verification documents (admin).
  """
  def list_pending_verification_documents do
    @verification_document_repository.list_pending()
  end

  @doc """
  List verification documents with provider info for admin review.

  Accepts an optional status filter atom:
  - `nil` - All documents (newest first)
  - `:pending` - Pending documents (oldest first, FIFO)
  - `:approved` - Approved documents (newest first)
  - `:rejected` - Rejected documents (newest first)
  """
  @spec list_verification_documents_for_admin(VerificationDocument.status() | nil) ::
          {:ok, [ForStoringVerificationDocuments.admin_review_result()]}
  def list_verification_documents_for_admin(status \\ nil) do
    @verification_document_repository.list_for_admin_review(status)
  end

  @doc """
  Get a single verification document with provider info for admin review.
  """
  @spec get_verification_document_for_admin(String.t()) ::
          {:ok, ForStoringVerificationDocuments.admin_review_result()} | {:error, :not_found}
  def get_verification_document_for_admin(document_id) do
    @verification_document_repository.get_for_admin_review(document_id)
  end

  @doc """
  Get a verification document with a verified preview URL for admin review.
  """
  @spec get_verification_document_preview(String.t()) ::
          {:ok,
           %{
             document: VerificationDocument.t(),
             provider_business_name: String.t(),
             signed_url: String.t() | nil,
             preview_type: :image | :pdf | :other
           }}
          | {:error, :not_found}
  def get_verification_document_preview(document_id) do
    GetVerificationDocumentPreview.execute(document_id)
  end

  # ============================================================================
  # Provider Verification
  # ============================================================================

  @doc """
  Verify a provider (admin only).
  """
  def verify_provider(provider_id, admin_id) do
    VerifyProvider.execute(%{
      provider_id: provider_id,
      admin_id: admin_id
    })
  end

  @doc """
  Unverify a provider (admin only).
  """
  def unverify_provider(provider_id, admin_id) do
    UnverifyProvider.execute(%{
      provider_id: provider_id,
      admin_id: admin_id
    })
  end

  @doc """
  List all verified provider IDs (for projections).
  """
  def list_verified_provider_ids do
    @provider_repository.list_verified_ids()
  end

  # ============================================================================
  # Staff Members
  # ============================================================================

  @doc """
  Creates a new staff member for a provider.
  """
  def create_staff_member(attrs) when is_map(attrs) do
    CreateStaffMember.execute(attrs)
  end

  @doc """
  Updates an existing staff member.
  """
  def update_staff_member(staff_id, attrs) when is_binary(staff_id) and is_map(attrs) do
    UpdateStaffMember.execute(staff_id, attrs)
  end

  @doc """
  Deletes a staff member by ID.
  """
  def delete_staff_member(staff_id) when is_binary(staff_id) do
    DeleteStaffMember.execute(staff_id)
  end

  @doc """
  Retrieves a single staff member by ID.
  """
  def get_staff_member(staff_id) when is_binary(staff_id) do
    @staff_repository.get(staff_id)
  end

  @doc """
  Lists all staff members for a provider, ordered by insertion date.
  """
  def list_staff_members(provider_id) when is_binary(provider_id) do
    @staff_repository.list_by_provider(provider_id)
  end

  @doc """
  Lists active staff members for a provider.
  """
  def list_active_staff_members(provider_id) when is_binary(provider_id) do
    @staff_repository.list_active_by_provider(provider_id)
  end

  @doc """
  Returns a changeset for tracking staff member form changes.
  """
  def change_staff_member(%StaffMember{} = staff, attrs \\ %{}) do
    ChangeStaffMember.execute(staff, attrs)
  end

  @doc """
  Returns the full name of a staff member.
  """
  @spec staff_member_full_name(StaffMember.t()) :: String.t()
  def staff_member_full_name(%StaffMember{} = staff) do
    StaffMember.full_name(staff)
  end

  @doc """
  Returns an empty changeset for a new staff member form.
  """
  def new_staff_member_changeset(attrs \\ %{}) do
    ChangeStaffMember.new_changeset(attrs)
  end
end
