defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentMapper do
  @moduledoc """
  Maps between domain Enrollment entities and EnrollmentSchema Ecto structs.

  This adapter provides bidirectional conversion:
  - to_domain/1: EnrollmentSchema → Enrollment (for reading from database)
  - to_schema/1: Enrollment → EnrollmentSchema attributes (for creating/updating in database)
  - to_domain_list/1: [EnrollmentSchema] → [Enrollment] (convenience for collections)

  ## Design Note: to_schema Excludes Database-Managed Fields

  The `to_schema/1` function intentionally excludes:
  - `id` - Managed by Ecto on insert (conditionally included via maybe_add_id/2)
  - `inserted_at`, `updated_at` - Managed by Ecto timestamps
  """

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Enrollment.Domain.Models.Enrollment

  @doc """
  Converts an Ecto EnrollmentSchema to a domain Enrollment entity.

  Returns the domain Enrollment struct with all fields mapped from the schema.
  UUIDs are converted to strings to maintain domain independence from Ecto types.
  Status is converted from string to atom.
  """
  @spec to_domain(EnrollmentSchema.t()) :: Enrollment.t()
  def to_domain(%EnrollmentSchema{} = schema) do
    %Enrollment{
      id: to_string(schema.id),
      program_id: to_string(schema.program_id),
      child_id: to_string(schema.child_id),
      parent_id: to_string(schema.parent_id),
      status: string_to_status(schema.status),
      enrolled_at: schema.enrolled_at,
      confirmed_at: schema.confirmed_at,
      completed_at: schema.completed_at,
      cancelled_at: schema.cancelled_at,
      cancellation_reason: schema.cancellation_reason,
      subtotal: schema.subtotal,
      vat_amount: schema.vat_amount,
      card_fee_amount: schema.card_fee_amount,
      total_amount: schema.total_amount,
      payment_method: schema.payment_method,
      special_requirements: schema.special_requirements,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain Enrollment entity to EnrollmentSchema attributes map.

  Returns a map suitable for Ecto changeset operations (insert/update).
  Status is converted from atom to string.
  """
  @spec to_schema(Enrollment.t()) :: map()
  def to_schema(%Enrollment{} = enrollment) do
    %{
      program_id: enrollment.program_id,
      child_id: enrollment.child_id,
      parent_id: enrollment.parent_id,
      status: status_to_string(enrollment.status),
      enrolled_at: enrollment.enrolled_at,
      confirmed_at: enrollment.confirmed_at,
      completed_at: enrollment.completed_at,
      cancelled_at: enrollment.cancelled_at,
      cancellation_reason: enrollment.cancellation_reason,
      subtotal: enrollment.subtotal,
      vat_amount: enrollment.vat_amount,
      card_fee_amount: enrollment.card_fee_amount,
      total_amount: enrollment.total_amount,
      payment_method: enrollment.payment_method,
      special_requirements: enrollment.special_requirements
    }
    |> maybe_add_id(enrollment.id)
  end

  @doc """
  Converts a list of EnrollmentSchema structs to a list of domain Enrollment entities.

  This is a convenience function for mapping collections returned from database queries.
  """
  @spec to_domain_list([EnrollmentSchema.t()]) :: [Enrollment.t()]
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end

  defp string_to_status(nil), do: :pending
  defp string_to_status(status) when is_binary(status), do: String.to_existing_atom(status)

  defp status_to_string(nil), do: "pending"
  defp status_to_string(status) when is_atom(status), do: Atom.to_string(status)

  defp maybe_add_id(attrs, nil), do: attrs
  defp maybe_add_id(attrs, id), do: Map.put(attrs, :id, id)
end
