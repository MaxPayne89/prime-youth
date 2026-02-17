defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapperTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema
  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  describe "to_domain/1" do
    test "maps schema to domain model" do
      id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      schema = %EnrollmentPolicySchema{
        id: id,
        program_id: program_id,
        min_enrollment: 5,
        max_enrollment: 20,
        inserted_at: now,
        updated_at: now
      }

      result = EnrollmentPolicyMapper.to_domain(schema)

      assert %EnrollmentPolicy{} = result
      assert result.id == to_string(id)
      assert result.program_id == to_string(program_id)
      assert result.min_enrollment == 5
      assert result.max_enrollment == 20
      assert result.inserted_at == now
      assert result.updated_at == now
    end

    test "maps schema with nil optional fields" do
      id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      schema = %EnrollmentPolicySchema{
        id: id,
        program_id: program_id,
        min_enrollment: nil,
        max_enrollment: nil,
        inserted_at: nil,
        updated_at: nil
      }

      result = EnrollmentPolicyMapper.to_domain(schema)

      assert result.min_enrollment == nil
      assert result.max_enrollment == nil
    end
  end

  describe "to_schema_attrs/1" do
    test "maps attrs to schema-compatible map" do
      attrs = %{program_id: "prog-1", min_enrollment: 5, max_enrollment: 20}
      result = EnrollmentPolicyMapper.to_schema_attrs(attrs)

      assert result.program_id == "prog-1"
      assert result.min_enrollment == 5
      assert result.max_enrollment == 20
    end

    test "filters out extraneous keys" do
      attrs = %{program_id: "prog-1", max_enrollment: 10, extra_key: "ignored"}
      result = EnrollmentPolicyMapper.to_schema_attrs(attrs)

      refute Map.has_key?(result, :extra_key)
    end
  end
end
