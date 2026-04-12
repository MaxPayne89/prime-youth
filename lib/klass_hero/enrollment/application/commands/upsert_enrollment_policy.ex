defmodule KlassHero.Enrollment.Application.Commands.UpsertEnrollmentPolicy do
  @moduledoc """
  Use case for creating or updating enrollment capacity policy for a program.

  Uses upsert semantics — if a policy already exists for the program_id, it is updated.
  """

  @policy_repo Application.compile_env!(:klass_hero, [
                 :enrollment,
                 :for_managing_enrollment_policies
               ])

  @doc """
  Creates or updates an enrollment policy for a program.

  ## Parameters

  - `attrs` - Map with :program_id (required), :min_enrollment, :max_enrollment (at least one required)

  ## Returns

  - `{:ok, EnrollmentPolicy.t()}` on success
  - `{:error, term()}` on validation failure
  """
  def execute(attrs) when is_map(attrs) do
    @policy_repo.upsert(attrs)
  end
end
