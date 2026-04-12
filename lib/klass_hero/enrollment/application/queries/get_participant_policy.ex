defmodule KlassHero.Enrollment.Application.Queries.GetParticipantPolicy do
  @moduledoc """
  Query for retrieving the participant eligibility policy for a program.
  """

  @participant_policy_repo Application.compile_env!(:klass_hero, [
                             :enrollment,
                             :for_managing_participant_policies
                           ])

  @doc """
  Returns the participant policy for a program.

  ## Returns

  - `{:ok, ParticipantPolicy.t()}` if a policy exists
  - `{:error, :not_found}` if no policy is set
  """
  def execute(program_id) when is_binary(program_id) do
    @participant_policy_repo.get_by_program_id(program_id)
  end
end
