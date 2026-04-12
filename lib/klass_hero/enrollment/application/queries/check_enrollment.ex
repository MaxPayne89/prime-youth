defmodule KlassHero.Enrollment.Application.Queries.CheckEnrollment do
  @moduledoc """
  Use case for checking if a parent is actively enrolled in a program.

  Used by the Messaging context to verify enrollment status without
  directly querying Enrollment schemas.
  """

  require Logger

  @enrollment_repository Application.compile_env!(:klass_hero, [
                           :enrollment,
                           :for_querying_enrollments
                         ])

  @spec execute(binary(), binary()) :: boolean()
  def execute(program_id, identity_id) when is_binary(program_id) and is_binary(identity_id) do
    Logger.debug("[Enrollment.CheckEnrollment] Checking",
      program_id: program_id,
      identity_id: identity_id
    )

    @enrollment_repository.enrolled?(program_id, identity_id)
  end
end
