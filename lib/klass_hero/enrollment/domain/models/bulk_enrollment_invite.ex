defmodule KlassHero.Enrollment.Domain.Models.BulkEnrollmentInvite do
  @moduledoc """
  Domain entity for a bulk enrollment invite in the Enrollment bounded context.

  Represents a denormalized staging record created from CSV import. When a
  guardian acts on the invite, real domain entities (User, ParentProfile,
  Child, Enrollment, Consents) are created from this data.

  This is a pure domain model with no persistence concerns.
  """

  @enforce_keys [
    :id,
    :program_id,
    :provider_id,
    :status,
    :guardian_email,
    :child_first_name,
    :child_last_name
  ]

  defstruct [
    :id,
    :program_id,
    :provider_id,
    :child_first_name,
    :child_last_name,
    :child_date_of_birth,
    :guardian_email,
    :guardian_first_name,
    :guardian_last_name,
    :guardian2_email,
    :guardian2_first_name,
    :guardian2_last_name,
    :school_grade,
    :school_name,
    :medical_conditions,
    :nut_allergy,
    :consent_photo_marketing,
    :consent_photo_social_media,
    :status,
    :invite_token,
    :invite_sent_at,
    :registered_at,
    :enrolled_at,
    :enrollment_id,
    :error_details
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          program_id: String.t(),
          provider_id: String.t(),
          child_first_name: String.t(),
          child_last_name: String.t(),
          child_date_of_birth: Date.t() | nil,
          guardian_email: String.t(),
          guardian_first_name: String.t() | nil,
          guardian_last_name: String.t() | nil,
          guardian2_email: String.t() | nil,
          guardian2_first_name: String.t() | nil,
          guardian2_last_name: String.t() | nil,
          school_grade: non_neg_integer() | nil,
          school_name: String.t() | nil,
          medical_conditions: String.t() | nil,
          nut_allergy: boolean() | nil,
          consent_photo_marketing: boolean() | nil,
          consent_photo_social_media: boolean() | nil,
          status: String.t(),
          invite_token: String.t() | nil,
          invite_sent_at: DateTime.t() | nil,
          registered_at: DateTime.t() | nil,
          enrolled_at: DateTime.t() | nil,
          enrollment_id: String.t() | nil,
          error_details: String.t() | nil
        }

  @doc """
  Reconstructs a BulkEnrollmentInvite from persistence data.

  Skips business validation since data was validated on write.
  Uses `struct!/2` to enforce `@enforce_keys`.

  Returns:
  - `{:ok, invite}` if all required keys are present
  - `{:error, :invalid_persistence_data}` if required keys are missing
  """
  def from_persistence(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, :invalid_persistence_data}
  end

  @doc "Returns true if the invite is in `pending` status."
  @spec pending?(t()) :: boolean()
  def pending?(%__MODULE__{status: "pending"}), do: true
  def pending?(%__MODULE__{}), do: false

  @doc "Returns true if the invite is in `invite_sent` status."
  @spec invite_sent?(t()) :: boolean()
  def invite_sent?(%__MODULE__{status: "invite_sent"}), do: true
  def invite_sent?(%__MODULE__{}), do: false

  @doc "Generates a cryptographically secure URL-safe token for invite links."
  @spec generate_token() :: String.t()
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
