defmodule KlassHero.Enrollment.Application.Commands.SetParticipantPolicy do
  @moduledoc """
  Use case for creating or updating participant eligibility restrictions for a program.

  Uses upsert semantics — if a policy already exists for the program_id, it is updated.

  ## Events Published

  - `participant_policy_set` on successful upsert
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy
  alias KlassHero.Shared.EventDispatchHelper

  @context KlassHero.Enrollment

  @participant_policy_repository Application.compile_env!(:klass_hero, [
                                   :enrollment,
                                   :for_managing_participant_policies
                                 ])

  @spec execute(map()) :: {:ok, ParticipantPolicy.t()} | {:error, term()}
  def execute(attrs) when is_map(attrs) do
    with {:ok, policy} <- @participant_policy_repository.upsert(attrs) do
      publish_event(policy.program_id)
      {:ok, policy}
    end
  end

  defp publish_event(program_id) do
    program_id
    |> EnrollmentEvents.participant_policy_set()
    |> EventDispatchHelper.dispatch(@context)
  end
end
