defmodule KlassHero.Factory do
  @moduledoc """
  ExMachina factory for creating test data across the Klass Hero application.

  This factory provides builders for both domain entities and Ecto schemas,
  following the DDD/Ports & Adapters architecture.

  ## Usage

      # Build domain entity (for use case tests)
      program = build(:program)
      program = build(:program, title: "Custom Title")

      # Build Ecto schema (for repository tests)
      schema = build(:program_schema)

      # Insert into database (for integration tests)
      program = insert(:program_schema)

      # Named variations
      program = build(:soccer_program)
      program = build(:dance_program)

      # Build lists
      programs = build_list(3, :program)
  """

  use ExMachina.Ecto, repo: KlassHero.Repo

  alias KlassHero.AccountsFixtures
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Enrollment.Domain.Models.Enrollment
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ConsentSchema
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
  alias KlassHero.Family.Domain.Models.Child
  alias KlassHero.Family.Domain.Models.Consent
  alias KlassHero.Family.Domain.Models.ParentProfile
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.VerificationDocumentSchema
  alias KlassHero.Provider.Domain.Models.ProviderProfile

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.{
    ConversationSchema,
    MessageSchema,
    ParticipantSchema
  }

  alias KlassHero.Messaging.Domain.Models.{Conversation, Message, Participant}
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.BehavioralNoteSchema
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @doc """
  Factory for creating Program domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      program = build(:program)
      program = build(:program, title: "Soccer Camp", spots_available: 15)
  """
  def program_factory do
    %Program{
      id:
        sequence(
          :program_id,
          &"550e8400-e29b-41d4-a716-44665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      title: sequence(:program_title, &"Test Program #{&1}"),
      description: "A great program for kids to learn and have fun",
      category: "education",
      schedule: "Mon-Fri 3-5pm",
      age_range: "6-10 years",
      price: Decimal.new("100.00"),
      pricing_period: "per month",
      spots_available: 10,
      icon_path: "/images/icons/default.svg",
      end_date: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ProgramSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.

  ## Examples

      schema = build(:program_schema)
      schema = insert(:program_schema, title: "Art Class")
  """
  def program_schema_factory do
    %ProgramSchema{
      id: Ecto.UUID.generate(),
      title: sequence(:program_schema_title, &"Test Program #{&1}"),
      description: "A great program for kids to learn and have fun",
      category: "education",
      schedule: "Mon-Fri 3-5pm",
      age_range: "6-10 years",
      price: Decimal.new("100.00"),
      pricing_period: "per month",
      spots_available: 10,
      icon_path: "/images/icons/default.svg",
      end_date: nil
    }
  end

  defp program_variant(overrides) do
    struct!(program_factory(), overrides)
  end

  @doc """
  Soccer program variant - commonly used in filter tests.
  """
  def soccer_program_factory do
    program_variant(%{
      id: "550e8400-e29b-41d4-a716-446655440001",
      title: "After School Soccer",
      description: "Learn soccer fundamentals in a fun environment",
      schedule: "Mon-Wed 3-5pm",
      age_range: "6-10 years",
      price: Decimal.new("150.00"),
      spots_available: 12,
      icon_path: "/images/icons/soccer.svg"
    })
  end

  @doc """
  Dance program variant - commonly used in filter tests.
  """
  def dance_program_factory do
    program_variant(%{
      id: "550e8400-e29b-41d4-a716-446655440002",
      title: "Summer Dance Camp",
      description: "Express yourself through creative movement and dance",
      schedule: "Tue-Thu 4-6pm",
      age_range: "7-12 years",
      price: Decimal.new("120.00"),
      spots_available: 8,
      icon_path: "/images/icons/dance.svg"
    })
  end

  @doc """
  Yoga program variant - commonly used in filter tests.
  """
  def yoga_program_factory do
    program_variant(%{
      id: "550e8400-e29b-41d4-a716-446655440003",
      title: "Kids Yoga Flow",
      description: "Mindfulness and movement for young yogis",
      schedule: "Sat 9-10am",
      age_range: "5-8 years",
      price: Decimal.new("80.00"),
      spots_available: 15,
      icon_path: "/images/icons/yoga.svg"
    })
  end

  @doc """
  Basketball program variant - commonly used in filter tests.
  """
  def basketball_program_factory do
    program_variant(%{
      id: "550e8400-e29b-41d4-a716-446655440004",
      title: "Basketball Training",
      description: "Develop basketball skills and teamwork",
      schedule: "Mon-Fri 4-6pm",
      age_range: "8-14 years",
      price: Decimal.new("200.00"),
      spots_available: 16,
      icon_path: "/images/icons/basketball.svg"
    })
  end

  @doc """
  Art program variant with special characters - tests normalization.
  """
  def art_program_factory do
    program_variant(%{
      id: "550e8400-e29b-41d4-a716-446655440005",
      title: "Art! & Crafts",
      description: "Creative arts and crafts exploration",
      schedule: "Wed 3-5pm",
      age_range: "5-10 years",
      price: Decimal.new("90.00"),
      spots_available: 12,
      icon_path: "/images/icons/art.svg"
    })
  end

  @doc """
  Build a standard set of sample programs for filter testing.

  Returns a list of 5 diverse programs commonly used in filter tests.

  ## Example

      programs = sample_programs()
      # Returns [soccer, dance, yoga, basketball, art]
  """
  def sample_programs do
    [
      build(:soccer_program),
      build(:dance_program),
      build(:yoga_program),
      build(:basketball_program),
      build(:art_program)
    ]
  end

  # =============================================================================
  # Family Context - Parent Profile Factories
  # =============================================================================

  @doc """
  Factory for creating ParentProfile domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      parent = build(:parent_profile)
      parent = build(:parent_profile, display_name: "Jane Doe", phone: "+1555123456")
  """
  def parent_profile_factory do
    %ParentProfile{
      id:
        sequence(
          :parent_id,
          &"550e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      identity_id:
        sequence(
          :parent_identity_id,
          &"660e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      display_name: sequence(:parent_display_name, &"Test Parent #{&1}"),
      phone: "+1234567890",
      location: "New York, NY",
      notification_preferences: %{email: true, sms: false},
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ParentProfileSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.

  ## Examples

      schema = build(:parent_profile_schema)
      schema = insert(:parent_profile_schema, display_name: "John Parent")
  """
  def parent_profile_schema_factory do
    %ParentProfileSchema{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      display_name: sequence(:parent_schema_display_name, &"Test Parent #{&1}"),
      phone: "+1234567890",
      location: "New York, NY",
      notification_preferences: %{email: true, sms: false}
    }
  end

  # Backwards-compatible aliases for Parent factories
  def parent_factory, do: parent_profile_factory()
  def parent_schema_factory, do: parent_profile_schema_factory()

  # =============================================================================
  # Provider Context - Provider Profile Factories
  # =============================================================================

  @doc """
  Factory for creating ProviderProfile domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      provider = build(:provider_profile)
      provider = build(:provider_profile, business_name: "Youth Sports", verified: true)
  """
  def provider_profile_factory do
    %ProviderProfile{
      id:
        sequence(
          :provider_id,
          &"770e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      identity_id:
        sequence(
          :provider_identity_id,
          &"880e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      business_name: sequence(:provider_business_name, &"Test Provider #{&1}"),
      description: "A great provider of youth activities and programs",
      phone: "+1234567890",
      website: "https://example.com",
      address: "123 Main St, City, State",
      logo_url: "https://example.com/logo.png",
      verified: false,
      verified_at: nil,
      categories: ["sports", "outdoor"],
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ProviderProfileSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.

  ## Examples

      schema = build(:provider_profile_schema)
      schema = insert(:provider_profile_schema, business_name: "Youth Arts Center")
  """
  def provider_profile_schema_factory do
    %ProviderProfileSchema{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      business_name: sequence(:provider_schema_business_name, &"Test Provider #{&1}"),
      description: "A great provider of youth activities and programs",
      phone: "+1234567890",
      website: "https://example.com",
      address: "123 Main St, City, State",
      logo_url: "https://example.com/logo.png",
      verified: false,
      verified_at: nil,
      categories: ["sports", "outdoor"],
      subscription_tier: "professional"
    }
  end

  # Backwards-compatible aliases for Provider factories
  def provider_factory, do: provider_profile_factory()
  def provider_schema_factory, do: provider_profile_schema_factory()

  @doc """
  Verified provider profile variant - commonly used for testing verified provider flows.
  """
  def verified_provider_profile_factory do
    build(:provider_profile, %{
      business_name: "Verified Sports Academy",
      verified: true,
      verified_at: ~U[2025-01-15 10:00:00Z],
      categories: ["sports", "certified", "outdoor"]
    })
  end

  # Backwards-compatible alias for verified provider factory
  def verified_provider_factory, do: verified_provider_profile_factory()

  # =============================================================================
  # Family Context - Child Factories
  # =============================================================================

  @doc """
  Factory for creating Child domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      child = build(:child)
      child = build(:child, first_name: "Alice", last_name: "Smith")
  """
  def child_factory do
    %Child{
      id:
        sequence(
          :child_id,
          &"550e8400-e29b-41d4-a716-66665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      parent_id:
        sequence(
          :child_parent_id,
          &"660e8400-e29b-41d4-a716-66665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      first_name: sequence(:child_first_name, &"Child#{&1}"),
      last_name: "Smith",
      date_of_birth: ~D[2018-06-15],
      emergency_contact: nil,
      support_needs: nil,
      allergies: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ChildSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a parent when inserted to avoid foreign key violations.

  ## Examples

      schema = build(:child_schema)
      schema = insert(:child_schema, first_name: "Bob")
  """
  def child_schema_factory do
    parent_schema = insert(:parent_profile_schema)

    %ChildSchema{
      id: Ecto.UUID.generate(),
      parent_id: parent_schema.id,
      first_name: sequence(:child_schema_first_name, &"Child#{&1}"),
      last_name: "Smith",
      date_of_birth: ~D[2018-06-15],
      emergency_contact: nil,
      support_needs: nil,
      allergies: nil
    }
  end

  # =============================================================================
  # Family Context - Consent Factories
  # =============================================================================

  @doc """
  Factory for creating Consent domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      consent = build(:consent)
      consent = build(:consent, consent_type: "photo")
  """
  def consent_factory do
    %Consent{
      id:
        sequence(
          :consent_id,
          &"550e8400-e29b-41d4-a716-77665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      parent_id:
        sequence(
          :consent_parent_id,
          &"660e8400-e29b-41d4-a716-77665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      child_id:
        sequence(
          :consent_child_id,
          &"550e8400-e29b-41d4-a716-66665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      consent_type: "provider_data_sharing",
      granted_at: ~U[2025-06-01 12:00:00Z],
      withdrawn_at: nil,
      inserted_at: ~U[2025-06-01 12:00:00Z],
      updated_at: ~U[2025-06-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ConsentSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a parent and child when inserted to avoid foreign key violations.

  ## Examples

      schema = build(:consent_schema)
      schema = insert(:consent_schema, consent_type: "photo")
  """
  def consent_schema_factory do
    child_schema = insert(:child_schema)

    %ConsentSchema{
      id: Ecto.UUID.generate(),
      parent_id: child_schema.parent_id,
      child_id: child_schema.id,
      consent_type: "provider_data_sharing",
      granted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      withdrawn_at: nil
    }
  end

  # =============================================================================
  # Provider Context - Verification Document Factories
  # =============================================================================

  @doc """
  Factory for creating VerificationDocumentSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a provider when inserted to avoid foreign key violations.

  ## Examples

      schema = insert(:verification_document_schema)
      schema = insert(:verification_document_schema, status: "approved")
  """
  def verification_document_schema_factory do
    provider = insert(:provider_profile_schema)

    %VerificationDocumentSchema{
      id: Ecto.UUID.generate(),
      provider_id: provider.id,
      document_type: "business_registration",
      file_url:
        "verification-docs/providers/#{provider.id}/#{System.unique_integer([:positive])}_doc.pdf",
      original_filename: "registration.pdf",
      status: "pending"
    }
  end

  @doc """
  Approved verification document variant.
  """
  def approved_verification_document_schema_factory do
    reviewer = AccountsFixtures.user_fixture(%{is_admin: true})

    struct!(
      verification_document_schema_factory(),
      %{
        status: "approved",
        reviewed_by_id: reviewer.id,
        reviewed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      }
    )
  end

  @doc """
  Rejected verification document variant.
  """
  def rejected_verification_document_schema_factory do
    reviewer = AccountsFixtures.user_fixture(%{is_admin: true})

    struct!(
      verification_document_schema_factory(),
      %{
        status: "rejected",
        rejection_reason: "Document is illegible",
        reviewed_by_id: reviewer.id,
        reviewed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      }
    )
  end

  # =============================================================================
  # Participation Context Factories
  # =============================================================================

  @doc """
  Factory for creating ProgramSession domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      session = build(:program_session)
      session = build(:program_session, status: :in_progress, max_capacity: 25)
  """
  def program_session_factory do
    %ProgramSession{
      id:
        sequence(
          :program_session_id,
          &"880e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      program_id:
        sequence(
          :program_session_program_id,
          &"550e8400-e29b-41d4-a716-44665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      session_date: Date.utc_today(),
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      max_capacity: 20,
      status: :scheduled,
      notes: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ProgramSessionSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a program when inserted to avoid foreign key violations.

  ## Examples

      schema = build(:program_session_schema)
      schema = insert(:program_session_schema, status: "in_progress")
  """
  def program_session_schema_factory do
    program_schema = insert(:program_schema)

    %ProgramSessionSchema{
      id: Ecto.UUID.generate(),
      program_id: program_schema.id,
      session_date: Date.utc_today(),
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      max_capacity: 20,
      status: "scheduled",
      notes: nil
    }
  end

  @doc """
  Factory for creating ParticipationRecord domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      record = build(:participation_record)
      record = build(:participation_record, status: :checked_in)
  """
  def participation_record_factory do
    %ParticipationRecord{
      id:
        sequence(
          :participation_record_id,
          &"990e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      session_id:
        sequence(
          :participation_record_session_id,
          &"880e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      child_id:
        sequence(
          :participation_record_child_id,
          &"550e8400-e29b-41d4-a716-66665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      parent_id: nil,
      provider_id: nil,
      status: :registered,
      check_in_at: nil,
      check_in_notes: nil,
      check_in_by: nil,
      check_out_at: nil,
      check_out_notes: nil,
      check_out_by: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ParticipationRecordSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a program session and child when inserted to avoid foreign key violations.

  ## Examples

      schema = build(:participation_record_schema)
      schema = insert(:participation_record_schema, status: :checked_in)
  """
  def participation_record_schema_factory do
    session_schema = insert(:program_session_schema)
    child_schema = insert(:child_schema)

    %ParticipationRecordSchema{
      id: Ecto.UUID.generate(),
      session_id: session_schema.id,
      child_id: child_schema.id,
      parent_id: child_schema.parent_id,
      provider_id: nil,
      status: :registered,
      check_in_at: nil,
      check_in_notes: nil,
      check_in_by: nil,
      check_out_at: nil,
      check_out_notes: nil,
      check_out_by: nil
    }
  end

  # =============================================================================
  # Behavioral Note Factories
  # =============================================================================

  @doc """
  Factory for creating BehavioralNote domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      note = build(:behavioral_note)
      note = build(:behavioral_note, content: "Custom observation")
  """
  def behavioral_note_factory do
    %BehavioralNote{
      id:
        sequence(
          :behavioral_note_id,
          &"aa1e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      participation_record_id:
        sequence(
          :behavioral_note_record_id,
          &"990e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      child_id:
        sequence(
          :behavioral_note_child_id,
          &"550e8400-e29b-41d4-a716-66665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      parent_id: nil,
      provider_id:
        sequence(
          :behavioral_note_provider_id,
          &"770e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      content: "Child was very engaged and cooperative during the session",
      status: :pending_approval,
      rejection_reason: nil,
      submitted_at: ~U[2025-06-01 12:00:00Z],
      reviewed_at: nil,
      inserted_at: ~U[2025-06-01 12:00:00Z],
      updated_at: ~U[2025-06-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating BehavioralNoteSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a participation record when inserted.

  ## Examples

      schema = insert(:behavioral_note_schema)
      schema = insert(:behavioral_note_schema, content: "Custom observation")
  """
  def behavioral_note_schema_factory do
    record =
      insert(:participation_record_schema,
        status: :checked_in,
        check_in_at: DateTime.utc_now(),
        check_in_by: Ecto.UUID.generate()
      )

    %BehavioralNoteSchema{
      id: Ecto.UUID.generate(),
      participation_record_id: record.id,
      child_id: record.child_id,
      parent_id: record.parent_id,
      provider_id: Ecto.UUID.generate(),
      content: "Child was very engaged and cooperative during the session",
      status: :pending_approval,
      rejection_reason: nil,
      submitted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      reviewed_at: nil
    }
  end

  @doc """
  Approved behavioral note domain entity variant.
  """
  def approved_behavioral_note_factory do
    build(:behavioral_note, %{
      status: :approved,
      reviewed_at: ~U[2025-06-02 12:00:00Z]
    })
  end

  @doc """
  Rejected behavioral note domain entity variant.
  """
  def rejected_behavioral_note_factory do
    build(:behavioral_note, %{
      status: :rejected,
      rejection_reason: "Please rephrase",
      reviewed_at: ~U[2025-06-02 12:00:00Z]
    })
  end

  @doc """
  Checked-in participation record variant for testing check-out flows.
  """
  def checked_in_participation_record_factory do
    now = DateTime.utc_now()
    provider_id = Ecto.UUID.generate()

    build(:participation_record, %{
      status: :checked_in,
      check_in_at: now,
      check_in_notes: "Arrived on time",
      check_in_by: provider_id,
      provider_id: provider_id
    })
  end

  @doc """
  Completed participation record variant (checked out) for testing submission flows.
  """
  def checked_out_participation_record_factory do
    check_in_at = DateTime.add(DateTime.utc_now(), -3600, :second)
    check_out_at = DateTime.utc_now()
    provider_id = Ecto.UUID.generate()

    build(:participation_record, %{
      status: :checked_out,
      check_in_at: check_in_at,
      check_in_notes: "Arrived on time",
      check_in_by: provider_id,
      check_out_at: check_out_at,
      check_out_notes: "Picked up by parent",
      check_out_by: provider_id,
      provider_id: provider_id
    })
  end

  # =============================================================================
  # Enrollment Context Factories
  # =============================================================================

  @doc """
  Factory for creating Enrollment domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      enrollment = build(:enrollment)
      enrollment = build(:enrollment, status: :confirmed)
  """
  def enrollment_factory do
    %Enrollment{
      id:
        sequence(
          :enrollment_id,
          &"aa0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      program_id:
        sequence(
          :enrollment_program_id,
          &"550e8400-e29b-41d4-a716-44665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      child_id:
        sequence(
          :enrollment_child_id,
          &"550e8400-e29b-41d4-a716-66665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      parent_id:
        sequence(
          :enrollment_parent_id,
          &"550e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      status: :pending,
      enrolled_at: DateTime.utc_now(),
      confirmed_at: nil,
      completed_at: nil,
      cancelled_at: nil,
      cancellation_reason: nil,
      subtotal: Decimal.new("100.00"),
      vat_amount: Decimal.new("19.00"),
      card_fee_amount: Decimal.new("2.00"),
      total_amount: Decimal.new("121.00"),
      payment_method: "card",
      special_requirements: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating EnrollmentSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a program, child, and parent when inserted to avoid foreign key violations.

  ## Examples

      schema = build(:enrollment_schema)
      schema = insert(:enrollment_schema, status: "confirmed")
  """
  def enrollment_schema_factory do
    program_schema = insert(:program_schema)
    child_schema = insert(:child_schema)

    %EnrollmentSchema{
      id: Ecto.UUID.generate(),
      program_id: program_schema.id,
      child_id: child_schema.id,
      parent_id: child_schema.parent_id,
      status: "pending",
      enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second),
      confirmed_at: nil,
      completed_at: nil,
      cancelled_at: nil,
      cancellation_reason: nil,
      subtotal: Decimal.new("100.00"),
      vat_amount: Decimal.new("19.00"),
      card_fee_amount: Decimal.new("2.00"),
      total_amount: Decimal.new("121.00"),
      payment_method: "card",
      special_requirements: nil
    }
  end

  @doc """
  Confirmed enrollment domain entity variant.
  """
  def confirmed_enrollment_factory do
    build(:enrollment, %{
      status: :confirmed,
      confirmed_at: DateTime.utc_now()
    })
  end

  @doc """
  Cancelled enrollment domain entity variant.
  """
  def cancelled_enrollment_factory do
    build(:enrollment, %{
      status: :cancelled,
      cancelled_at: DateTime.utc_now(),
      cancellation_reason: "User requested cancellation"
    })
  end

  # =============================================================================
  # Messaging Context Factories
  # =============================================================================

  @doc """
  Factory for creating Conversation domain entities (pure Elixir structs).

  Used in domain model tests where we don't need database persistence.

  ## Examples

      conversation = build(:conversation)
      conversation = build(:conversation, type: :program_broadcast, program_id: "...")
  """
  def conversation_factory do
    provider_id = Ecto.UUID.generate()

    %Conversation{
      id:
        sequence(
          :conversation_id,
          &"bb0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      type: :direct,
      provider_id: provider_id,
      program_id: nil,
      subject: nil,
      archived_at: nil,
      retention_until: nil,
      lock_version: 1,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z],
      participants: [],
      messages: []
    }
  end

  @doc """
  Factory for creating ConversationSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a provider when inserted to avoid foreign key violations.

  ## Examples

      schema = build(:conversation_schema)
      schema = insert(:conversation_schema, type: "program_broadcast")
  """
  def conversation_schema_factory do
    provider = insert(:provider_profile_schema)

    %ConversationSchema{
      id: Ecto.UUID.generate(),
      type: "direct",
      provider_id: provider.id,
      program_id: nil,
      subject: nil,
      archived_at: nil,
      retention_until: nil,
      lock_version: 1
    }
  end

  @doc """
  Broadcast conversation variant for program-wide announcements.
  """
  def broadcast_conversation_factory do
    provider_id = Ecto.UUID.generate()
    program_id = Ecto.UUID.generate()

    build(:conversation, %{
      type: :program_broadcast,
      provider_id: provider_id,
      program_id: program_id,
      subject: "Important Update"
    })
  end

  @doc """
  Broadcast conversation schema variant for program-wide announcements.
  Requires a program to be created first.
  """
  def broadcast_conversation_schema_factory do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema)

    %ConversationSchema{
      id: Ecto.UUID.generate(),
      type: "program_broadcast",
      provider_id: provider.id,
      program_id: program.id,
      subject: "Important Update",
      archived_at: nil,
      retention_until: nil,
      lock_version: 1
    }
  end

  @doc """
  Factory for creating Message domain entities (pure Elixir structs).

  Used in domain model tests where we don't need database persistence.

  ## Examples

      message = build(:message)
      message = build(:message, content: "Hello!", message_type: :system)
  """
  def message_factory do
    %Message{
      id:
        sequence(
          :message_id,
          &"cc0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      conversation_id:
        sequence(
          :message_conversation_id,
          &"bb0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      sender_id:
        sequence(
          :message_sender_id,
          &"dd0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      content: sequence(:message_content, &"Test message #{&1}"),
      message_type: :text,
      deleted_at: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating MessageSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a conversation and user when inserted.

  ## Examples

      schema = build(:message_schema)
      schema = insert(:message_schema, content: "Hello world!")
  """
  def message_schema_factory do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()

    # Add user as participant
    insert(:participant_schema,
      conversation_id: conversation.id,
      user_id: user.id
    )

    %MessageSchema{
      id: Ecto.UUID.generate(),
      conversation_id: conversation.id,
      sender_id: user.id,
      content: sequence(:message_schema_content, &"Test message #{&1}"),
      message_type: "text",
      deleted_at: nil
    }
  end

  @doc """
  System message variant for automated messages.
  """
  def system_message_factory do
    build(:message, %{
      message_type: :system,
      content: "User joined the conversation"
    })
  end

  @doc """
  Factory for creating Participant domain entities (pure Elixir structs).

  Used in domain model tests where we don't need database persistence.

  ## Examples

      participant = build(:participant)
      participant = build(:participant, last_read_at: DateTime.utc_now())
  """
  def participant_factory do
    %Participant{
      id:
        sequence(
          :participant_id,
          &"ee0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      conversation_id:
        sequence(
          :participant_conversation_id,
          &"bb0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      user_id:
        sequence(
          :participant_user_id,
          &"ff0e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      last_read_at: nil,
      joined_at: DateTime.utc_now(),
      left_at: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ParticipantSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.

  ## Examples

      schema = build(:participant_schema)
      schema = insert(:participant_schema, conversation_id: conv.id, user_id: user.id)
  """
  def participant_schema_factory do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()

    %ParticipantSchema{
      id: Ecto.UUID.generate(),
      conversation_id: conversation.id,
      user_id: user.id,
      last_read_at: nil,
      joined_at: DateTime.utc_now(),
      left_at: nil
    }
  end
end
