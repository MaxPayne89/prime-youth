defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapper do
  @moduledoc """
  Maps between EnrollmentPolicy domain model and Ecto schema.

  Provides:
  - to_domain/1: EnrollmentPolicySchema -> EnrollmentPolicy (reading from database)
  - to_schema_attrs/1: map -> map (preparing attributes for Ecto changeset)
  """

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema
  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  @doc """
  Converts an Ecto EnrollmentPolicySchema to a domain EnrollmentPolicy entity.

  UUIDs are converted to strings to maintain domain independence from Ecto types.
  """
  @spec to_domain(EnrollmentPolicySchema.t()) :: EnrollmentPolicy.t()
  def to_domain(%EnrollmentPolicySchema{} = schema) do
    %EnrollmentPolicy{
      id: to_string(schema.id),
      program_id: to_string(schema.program_id),
      min_enrollment: schema.min_enrollment,
      max_enrollment: schema.max_enrollment,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Transforms a map of attributes into a schema-compatible attributes map.

  Extracts only the fields relevant to the enrollment_policies table,
  filtering out any extraneous keys.
  """
  @spec to_schema_attrs(map()) :: map()
  def to_schema_attrs(attrs) when is_map(attrs) do
    %{
      program_id: attrs[:program_id],
      min_enrollment: attrs[:min_enrollment],
      max_enrollment: attrs[:max_enrollment]
    }
  end
end
