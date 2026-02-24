defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEvents do
  @moduledoc """
  Factory module for creating Enrollment domain events.

  ## Events

  - `:participant_policy_set` - Emitted when a provider creates or updates
    participant eligibility restrictions for a program (upsert semantics).
  - `:bulk_invites_imported` - Emitted after a CSV/bulk import creates
    enrollment invite records for one or more programs.
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

  @doc """
  Creates a `:bulk_invites_imported` event after a batch CSV import.

  ## Parameters

  - `provider_id` — the provider who performed the import
  - `program_ids` — list of program IDs that received invites
  - `count` — total number of invite records created
  - `opts` — forwarded to `DomainEvent.new/5` (e.g. `:correlation_id`)
  """
  def bulk_invites_imported(provider_id, program_ids, count, opts \\ [])

  def bulk_invites_imported(provider_id, program_ids, count, opts)
      when is_binary(provider_id) and byte_size(provider_id) > 0 and is_list(program_ids) and
             is_integer(count) do
    DomainEvent.new(
      :bulk_invites_imported,
      provider_id,
      @aggregate_type,
      %{provider_id: provider_id, program_ids: program_ids, count: count},
      opts
    )
  end

  def bulk_invites_imported(provider_id, _program_ids, _count, _opts) do
    raise ArgumentError,
          "bulk_invites_imported/4 requires a non-empty provider_id string, " <>
            "a list of program_ids, and an integer count, got: #{inspect(provider_id)}"
  end
end
