defmodule KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEvents do
  @moduledoc """
  Factory module for creating Enrollment integration events.

  Integration events are the public contract between bounded contexts.

  ## Events

  - `:participant_policy_set` - Emitted when participant eligibility restrictions
    are created or updated. Downstream contexts can react (e.g., search indexing).
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :enrollment
  @entity_type :participant_policy

  def participant_policy_set(program_id, payload \\ %{}, opts \\ [])

  def participant_policy_set(program_id, payload, opts)
      when is_binary(program_id) and byte_size(program_id) > 0 do
    base_payload = %{program_id: program_id}

    IntegrationEvent.new(
      :participant_policy_set,
      @source_context,
      @entity_type,
      program_id,
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
