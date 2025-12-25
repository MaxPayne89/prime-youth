defmodule PrimeYouth.Factory do
  @moduledoc """
  ExMachina factory for creating test data across the Prime Youth application.

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

  use ExMachina.Ecto, repo: PrimeYouth.Repo

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession
  alias PrimeYouth.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias PrimeYouth.Family.Domain.Models.Child
  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Schemas.ParentSchema
  alias PrimeYouth.Parenting.Domain.Models.Parent
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchema
  alias PrimeYouth.Providing.Domain.Models.Provider

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
      schedule: "Mon-Fri 3-5pm",
      age_range: "6-10 years",
      price: Decimal.new("100.00"),
      pricing_period: "per month",
      spots_available: 10,
      gradient_class: "bg-gradient-to-br from-blue-400 to-green-500",
      icon_path: "/images/icons/default.svg",
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
      schedule: "Mon-Fri 3-5pm",
      age_range: "6-10 years",
      price: Decimal.new("100.00"),
      pricing_period: "per month",
      spots_available: 10,
      gradient_class: "bg-gradient-to-br from-blue-400 to-green-500",
      icon_path: "/images/icons/default.svg"
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
      gradient_class: "bg-gradient-to-br from-green-400 to-blue-500",
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
      gradient_class: "bg-gradient-to-br from-purple-400 to-pink-500",
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
      gradient_class: "bg-gradient-to-br from-teal-400 to-cyan-500",
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
      gradient_class: "bg-gradient-to-br from-orange-400 to-red-500",
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
      gradient_class: "bg-gradient-to-br from-yellow-400 to-orange-500",
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
  # Parenting Context Factories
  # =============================================================================

  @doc """
  Factory for creating Parent domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      parent = build(:parent)
      parent = build(:parent, display_name: "Jane Doe", phone: "+1555123456")
  """
  def parent_factory do
    %Parent{
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
  Factory for creating ParentSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.

  ## Examples

      schema = build(:parent_schema)
      schema = insert(:parent_schema, display_name: "John Parent")
  """
  def parent_schema_factory do
    %ParentSchema{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      display_name: sequence(:parent_schema_display_name, &"Test Parent #{&1}"),
      phone: "+1234567890",
      location: "New York, NY",
      notification_preferences: %{email: true, sms: false}
    }
  end

  # =============================================================================
  # Providing Context Factories
  # =============================================================================

  @doc """
  Factory for creating Provider domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      provider = build(:provider)
      provider = build(:provider, business_name: "Youth Sports", verified: true)
  """
  def provider_factory do
    %Provider{
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
  Factory for creating ProviderSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.

  ## Examples

      schema = build(:provider_schema)
      schema = insert(:provider_schema, business_name: "Youth Arts Center")
  """
  def provider_schema_factory do
    %ProviderSchema{
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
      categories: ["sports", "outdoor"]
    }
  end

  @doc """
  Verified provider variant - commonly used for testing verified provider flows.
  """
  def verified_provider_factory do
    build(:provider, %{
      business_name: "Verified Sports Academy",
      verified: true,
      verified_at: ~U[2025-01-15 10:00:00Z],
      categories: ["sports", "certified", "outdoor"]
    })
  end

  # =============================================================================
  # Family Context Factories
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
      notes: nil,
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
    parent_schema = insert(:parent_schema)

    %ChildSchema{
      id: Ecto.UUID.generate(),
      parent_id: parent_schema.id,
      first_name: sequence(:child_schema_first_name, &"Child#{&1}"),
      last_name: "Smith",
      date_of_birth: ~D[2018-06-15],
      notes: nil
    }
  end

  # =============================================================================
  # Attendance Context Factories
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
  Factory for creating AttendanceRecord domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      record = build(:attendance_record)
      record = build(:attendance_record, status: :checked_in)
  """
  def attendance_record_factory do
    %AttendanceRecord{
      id:
        sequence(
          :attendance_record_id,
          &"990e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      session_id:
        sequence(
          :attendance_record_session_id,
          &"880e8400-e29b-41d4-a716-55665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      child_id:
        sequence(
          :attendance_record_child_id,
          &"550e8400-e29b-41d4-a716-66665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      parent_id: nil,
      provider_id: nil,
      status: :expected,
      check_in_at: nil,
      check_in_notes: nil,
      check_in_by: nil,
      check_out_at: nil,
      check_out_notes: nil,
      check_out_by: nil,
      submitted: false,
      submitted_at: nil,
      submitted_by: nil,
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating AttendanceRecordSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.
  Automatically creates a program session and child when inserted to avoid foreign key violations.

  ## Examples

      schema = build(:attendance_record_schema)
      schema = insert(:attendance_record_schema, status: "checked_in")
  """
  def attendance_record_schema_factory do
    session_schema = insert(:program_session_schema)
    child_schema = insert(:child_schema)

    %AttendanceRecordSchema{
      id: Ecto.UUID.generate(),
      session_id: session_schema.id,
      child_id: child_schema.id,
      parent_id: child_schema.parent_id,
      provider_id: nil,
      status: "expected",
      check_in_at: nil,
      check_in_notes: nil,
      check_in_by: nil,
      check_out_at: nil,
      check_out_notes: nil,
      check_out_by: nil,
      submitted: false,
      submitted_at: nil,
      submitted_by: nil
    }
  end

  @doc """
  Checked-in attendance record variant for testing check-out flows.
  """
  def checked_in_attendance_record_factory do
    now = DateTime.utc_now()
    provider_id = Ecto.UUID.generate()

    build(:attendance_record, %{
      status: :checked_in,
      check_in_at: now,
      check_in_notes: "Arrived on time",
      check_in_by: provider_id,
      provider_id: provider_id
    })
  end

  @doc """
  Completed attendance record variant (checked out) for testing submission flows.
  """
  def checked_out_attendance_record_factory do
    check_in_at = DateTime.add(DateTime.utc_now(), -3600, :second)
    check_out_at = DateTime.utc_now()
    provider_id = Ecto.UUID.generate()

    build(:attendance_record, %{
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
end
