defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentMapperTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Enrollment.Domain.Models.Enrollment

  describe "to_domain/1" do
    test "converts EnrollmentSchema to domain Enrollment" do
      schema = %EnrollmentSchema{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        status: "pending",
        enrolled_at: ~U[2025-01-15 10:00:00Z],
        confirmed_at: nil,
        completed_at: nil,
        cancelled_at: nil,
        cancellation_reason: nil,
        subtotal: Decimal.new("100.00"),
        vat_amount: Decimal.new("19.00"),
        card_fee_amount: Decimal.new("2.00"),
        total_amount: Decimal.new("121.00"),
        payment_method: "card",
        special_requirements: "Allergies: nuts",
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      enrollment = EnrollmentMapper.to_domain(schema)

      assert %Enrollment{} = enrollment
      assert enrollment.id == to_string(schema.id)
      assert enrollment.program_id == to_string(schema.program_id)
      assert enrollment.child_id == to_string(schema.child_id)
      assert enrollment.parent_id == to_string(schema.parent_id)
      assert enrollment.status == :pending
      assert enrollment.enrolled_at == schema.enrolled_at
      assert enrollment.subtotal == schema.subtotal
      assert enrollment.vat_amount == schema.vat_amount
      assert enrollment.card_fee_amount == schema.card_fee_amount
      assert enrollment.total_amount == schema.total_amount
      assert enrollment.payment_method == "card"
      assert enrollment.special_requirements == "Allergies: nuts"
    end

    test "converts status string to atom" do
      for {string_status, atom_status} <- [
            {"pending", :pending},
            {"confirmed", :confirmed},
            {"completed", :completed},
            {"cancelled", :cancelled}
          ] do
        schema = build_schema(status: string_status)
        enrollment = EnrollmentMapper.to_domain(schema)
        assert enrollment.status == atom_status
      end
    end

    test "handles nil status by defaulting to pending" do
      schema = build_schema(status: nil)

      enrollment = EnrollmentMapper.to_domain(schema)

      assert enrollment.status == :pending
    end

    test "preserves DateTime fields" do
      confirmed_at = ~U[2025-01-16 10:00:00Z]
      schema = build_schema(confirmed_at: confirmed_at)

      enrollment = EnrollmentMapper.to_domain(schema)

      assert enrollment.confirmed_at == confirmed_at
    end

    test "preserves Decimal fields" do
      subtotal = Decimal.new("250.50")
      schema = build_schema(subtotal: subtotal)

      enrollment = EnrollmentMapper.to_domain(schema)

      assert enrollment.subtotal == subtotal
    end
  end

  describe "to_schema/1" do
    test "converts domain Enrollment to schema attributes map" do
      enrollment = %Enrollment{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        status: :confirmed,
        enrolled_at: ~U[2025-01-15 10:00:00Z],
        confirmed_at: ~U[2025-01-16 10:00:00Z],
        completed_at: nil,
        cancelled_at: nil,
        cancellation_reason: nil,
        subtotal: Decimal.new("100.00"),
        vat_amount: Decimal.new("19.00"),
        card_fee_amount: Decimal.new("2.00"),
        total_amount: Decimal.new("121.00"),
        payment_method: "card",
        special_requirements: "Special diet",
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      attrs = EnrollmentMapper.to_schema(enrollment)

      assert is_map(attrs)
      assert attrs[:id] == enrollment.id
      assert attrs[:program_id] == enrollment.program_id
      assert attrs[:child_id] == enrollment.child_id
      assert attrs[:parent_id] == enrollment.parent_id
      assert attrs[:status] == "confirmed"
      assert attrs[:enrolled_at] == enrollment.enrolled_at
      assert attrs[:confirmed_at] == enrollment.confirmed_at
      assert attrs[:subtotal] == enrollment.subtotal
      assert attrs[:payment_method] == "card"
      assert attrs[:special_requirements] == "Special diet"
    end

    test "converts status atom to string" do
      for status <- [:pending, :confirmed, :completed, :cancelled] do
        enrollment = build_enrollment(status: status)
        attrs = EnrollmentMapper.to_schema(enrollment)
        assert attrs[:status] == Atom.to_string(status)
      end
    end

    test "handles nil status by defaulting to pending" do
      enrollment = build_enrollment(status: nil)

      attrs = EnrollmentMapper.to_schema(enrollment)

      assert attrs[:status] == "pending"
    end

    test "excludes id when nil" do
      enrollment = build_enrollment(id: nil)

      attrs = EnrollmentMapper.to_schema(enrollment)

      refute Map.has_key?(attrs, :id)
    end

    test "includes id when present" do
      id = Ecto.UUID.generate()
      enrollment = build_enrollment(id: id)

      attrs = EnrollmentMapper.to_schema(enrollment)

      assert attrs[:id] == id
    end

    test "excludes inserted_at and updated_at" do
      enrollment = build_enrollment()

      attrs = EnrollmentMapper.to_schema(enrollment)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end
  end

  describe "to_domain_list/1" do
    test "converts list of schemas to list of domain entities" do
      schemas = [
        build_schema(status: "pending"),
        build_schema(status: "confirmed"),
        build_schema(status: "completed")
      ]

      enrollments = EnrollmentMapper.to_domain_list(schemas)

      assert length(enrollments) == 3
      assert Enum.all?(enrollments, &match?(%Enrollment{}, &1))
      assert Enum.map(enrollments, & &1.status) == [:pending, :confirmed, :completed]
    end

    test "returns empty list for empty input" do
      assert EnrollmentMapper.to_domain_list([]) == []
    end
  end

  describe "round-trip conversion" do
    test "to_schema -> to_domain preserves data" do
      original =
        build_enrollment(
          status: :confirmed,
          subtotal: Decimal.new("99.99"),
          payment_method: "transfer"
        )

      attrs = EnrollmentMapper.to_schema(original)

      schema = struct(EnrollmentSchema, attrs)

      schema = %{
        schema
        | inserted_at: ~U[2025-01-01 12:00:00Z],
          updated_at: ~U[2025-01-01 12:00:00Z]
      }

      roundtrip = EnrollmentMapper.to_domain(schema)

      assert roundtrip.id == original.id
      assert roundtrip.program_id == original.program_id
      assert roundtrip.status == original.status
      assert roundtrip.subtotal == original.subtotal
      assert roundtrip.payment_method == original.payment_method
    end
  end

  defp build_schema(overrides) do
    defaults = %{
      id: Ecto.UUID.generate(),
      program_id: Ecto.UUID.generate(),
      child_id: Ecto.UUID.generate(),
      parent_id: Ecto.UUID.generate(),
      status: "pending",
      enrolled_at: ~U[2025-01-15 10:00:00Z],
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

    struct(EnrollmentSchema, Map.merge(defaults, Map.new(overrides)))
  end

  defp build_enrollment(overrides \\ []) do
    defaults = %{
      id: Ecto.UUID.generate(),
      program_id: Ecto.UUID.generate(),
      child_id: Ecto.UUID.generate(),
      parent_id: Ecto.UUID.generate(),
      status: :pending,
      enrolled_at: ~U[2025-01-15 10:00:00Z],
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

    struct(Enrollment, Map.merge(defaults, Map.new(overrides)))
  end
end
