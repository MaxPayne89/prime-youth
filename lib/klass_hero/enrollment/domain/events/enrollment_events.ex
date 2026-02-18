defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEvents do
  @moduledoc """
  Factory module for creating Enrollment domain events.

  ## Events

  - `:participant_policy_set` - Emitted when a provider creates or updates
    participant eligibility restrictions for a program (upsert semantics).
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent

  @aggregate_type :enrollment

  def participant_policy_set(program_id, payload \\ %{}, opts \\ [])

  def participant_policy_set(program_id, payload, opts)
      when is_binary(program_id) and byte_size(program_id) > 0 do
    base_payload = %{program_id: program_id}

    DomainEvent.new(
      :participant_policy_set,
      program_id,
      @aggregate_type,
      # Trigger: caller may pass a conflicting :program_id in payload
      # Why: base_payload contains the canonical program_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def participant_policy_set(program_id, _payload, _opts) do
    raise ArgumentError,
          "participant_policy_set/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
  end
end
