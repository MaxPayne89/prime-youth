defmodule KlassHero.Enrollment.Application.UseCases.SetParticipantPolicy do
  @moduledoc """
  Use case for creating or updating participant eligibility restrictions for a program.

  Uses upsert semantics — if a policy already exists for the program_id, it is updated.

  ## Events Published

  - `participant_policy_set` on successful upsert
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.DomainEventBus

  @context KlassHero.Enrollment

  @participant_policy_repository Application.compile_env!(:klass_hero, [
                                   :enrollment,
                                   :for_managing_participant_policies
                                 ])

  @doc """
  Creates or updates a participant policy for a program.

  ## Parameters

  - `attrs` - Map with :program_id (required) and restriction fields

  ## Returns

  - `{:ok, ParticipantPolicy.t()}` on success
  - `{:error, term()}` on validation or persistence failure
  """
  def execute(attrs) when is_map(attrs) do
    with {:ok, policy} <- @participant_policy_repository.upsert(attrs) do
      publish_event(policy.program_id)
      {:ok, policy}
    end
  end

  defp publish_event(program_id) do
    event = EnrollmentEvents.participant_policy_set(program_id)
    DomainEventBus.dispatch(@context, event)
  end
end
