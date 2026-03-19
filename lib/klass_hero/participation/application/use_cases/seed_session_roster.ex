defmodule KlassHero.Participation.Application.UseCases.SeedSessionRoster do
  @moduledoc """
  Use case for seeding a session roster with enrolled children.

  When a session is created, this use case queries the Enrollment context
  (via ACL) for active enrollments on the session's program, then bulk-inserts
  participation records with `:registered` status.

  ## Business Rules

  - All enrolled children are registered regardless of session max_capacity.
    Capacity is a scheduling/enrollment concern, not a roster gate.
  - Duplicate registrations are silently skipped (ON CONFLICT DO NOTHING).
  - Best-effort: failures are logged but do not propagate.

  ## Events Published

  - `roster_seeded` on successful seeding (even if count is 0)
  """

  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Participation

  @enrolled_children_resolver Application.compile_env!(:klass_hero, [
                                :participation,
                                :enrolled_children_resolver
                              ])
  @participation_repository Application.compile_env!(:klass_hero, [
                              :participation,
                              :participation_repository
                            ])

  @doc """
  Seeds a session roster with enrolled children from the program.

  ## Parameters

  - `session_id` - ID of the newly created session
  - `program_id` - ID of the program to resolve enrollments from

  ## Returns

  - `:ok` always (best-effort)
  """
  @spec execute(String.t(), String.t()) :: :ok
  def execute(session_id, program_id) when is_binary(session_id) and is_binary(program_id) do
    child_ids = @enrolled_children_resolver.list_enrolled_child_ids(program_id)

    # Trigger: max_capacity is intentionally not checked here
    # Why: all enrolled children should appear on the roster — capacity is an enrollment-time
    #      concern, not a per-session roster gate. A class of 25 enrolled kids should see all 25
    #      on every session, even if max_capacity is set lower for scheduling purposes.
    # Outcome: all child_ids are passed to seed_batch without filtering
    {:ok, count} = @participation_repository.seed_batch(session_id, child_ids)

    Logger.info("[SeedSessionRoster] Seeded roster",
      session_id: session_id,
      program_id: program_id,
      enrolled: length(child_ids),
      inserted: count,
      skipped: length(child_ids) - count
    )

    publish_event(session_id, program_id, count)

    :ok
  rescue
    error ->
      Logger.error(
        "[SeedSessionRoster] Failed to seed roster: #{Exception.message(error)}",
        session_id: session_id,
        program_id: program_id,
        stacktrace: Exception.format_stacktrace(__STACKTRACE__)
      )

      :ok
  end

  defp publish_event(session_id, program_id, count) do
    event = ParticipationEvents.roster_seeded(session_id, program_id, count)
    DomainEventBus.dispatch(@context, event)
  end
end
