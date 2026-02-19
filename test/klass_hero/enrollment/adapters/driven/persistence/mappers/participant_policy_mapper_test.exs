defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.ParticipantPolicyMapperTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.ParticipantPolicyMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.ParticipantPolicySchema
  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy

  describe "to_domain/1" do
    test "maps schema to domain model with all fields" do
      id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      schema = %ParticipantPolicySchema{
        id: id,
        program_id: program_id,
        eligibility_at: "program_start",
        min_age_months: 48,
        max_age_months: 120,
        allowed_genders: ["male", "female"],
        min_grade: 1,
        max_grade: 6,
        inserted_at: now,
        updated_at: now
      }

      result = ParticipantPolicyMapper.to_domain(schema)

      assert %ParticipantPolicy{} = result
      assert result.id == to_string(id)
      assert result.program_id == to_string(program_id)
      assert result.eligibility_at == "program_start"
      assert result.min_age_months == 48
      assert result.max_age_months == 120
      assert result.allowed_genders == ["male", "female"]
      assert result.min_grade == 1
      assert result.max_grade == 6
      assert result.inserted_at == now
      assert result.updated_at == now
    end

    test "maps schema with nil optional fields" do
      id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      schema = %ParticipantPolicySchema{
        id: id,
        program_id: program_id,
        eligibility_at: "registration",
        min_age_months: nil,
        max_age_months: nil,
        allowed_genders: nil,
        min_grade: nil,
        max_grade: nil,
        inserted_at: nil,
        updated_at: nil
      }

      result = ParticipantPolicyMapper.to_domain(schema)

      assert result.min_age_months == nil
      assert result.max_age_months == nil
      assert result.allowed_genders == []
      assert result.min_grade == nil
      assert result.max_grade == nil
    end
  end

  describe "to_schema_attrs/1" do
    test "maps attrs to schema-compatible map" do
      attrs = %{
        program_id: "prog-1",
        eligibility_at: "registration",
        min_age_months: 48,
        max_age_months: 120,
        allowed_genders: ["female"],
        min_grade: 1,
        max_grade: 4
      }

      result = ParticipantPolicyMapper.to_schema_attrs(attrs)

      assert result.program_id == "prog-1"
      assert result.eligibility_at == "registration"
      assert result.min_age_months == 48
      assert result.max_age_months == 120
      assert result.allowed_genders == ["female"]
      assert result.min_grade == 1
      assert result.max_grade == 4
    end

    test "filters out extraneous keys" do
      attrs = %{program_id: "prog-1", min_age_months: 48, extra_key: "ignored"}
      result = ParticipantPolicyMapper.to_schema_attrs(attrs)

      refute Map.has_key?(result, :extra_key)
    end
  end
end
