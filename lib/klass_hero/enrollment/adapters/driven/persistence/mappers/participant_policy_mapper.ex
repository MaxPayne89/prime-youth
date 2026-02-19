defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.ParticipantPolicyMapper do
  @moduledoc """
  Maps between ParticipantPolicy domain model and Ecto schema.

  Provides:
  - to_domain/1: ParticipantPolicySchema -> ParticipantPolicy (reading from database)
  - to_schema_attrs/1: map -> map (preparing attributes for Ecto changeset)
  """

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.ParticipantPolicySchema
  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy

  @known_keys ~w(program_id eligibility_at min_age_months max_age_months allowed_genders min_grade max_grade)a

  @doc """
  Converts an Ecto ParticipantPolicySchema to a domain ParticipantPolicy entity.

  UUIDs are converted to strings to maintain domain independence from Ecto types.
  """
  @spec to_domain(ParticipantPolicySchema.t()) :: ParticipantPolicy.t()
  def to_domain(%ParticipantPolicySchema{} = schema) do
    %ParticipantPolicy{
      id: to_string(schema.id),
      program_id: to_string(schema.program_id),
      eligibility_at: schema.eligibility_at,
      min_age_months: schema.min_age_months,
      max_age_months: schema.max_age_months,
      allowed_genders: schema.allowed_genders || [],
      min_grade: schema.min_grade,
      max_grade: schema.max_grade,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Transforms a map of attributes into a schema-compatible attributes map.

  Extracts only the fields relevant to the participant_policies table,
  filtering out any extraneous keys. Only includes keys present in the
  input to preserve schema defaults for omitted fields.
  """
  @spec to_schema_attrs(map()) :: map()
  def to_schema_attrs(attrs) when is_map(attrs) do
    # Trigger: attrs may omit optional keys entirely
    # Why: schema defaults (e.g., eligibility_at: "registration") must apply
    #      when the caller doesn't provide a value; mapping missing keys as nil
    #      would override schema defaults during cast
    # Outcome: only keys present in the input are forwarded to the changeset
    @known_keys
    |> Enum.filter(&Map.has_key?(attrs, &1))
    |> Map.new(fn key -> {key, attrs[key]} end)
  end
end
