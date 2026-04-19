defmodule KlassHero.Enrollment.Application.Queries.ListEnrolledIdentityIds do
  @moduledoc """
  Use case for listing identity IDs of parents with active enrollments
  in a program.

  Used by the Messaging context to resolve program broadcast recipients
  without directly querying Enrollment schemas.
  """

  require Logger

  @enrollment_repository Application.compile_env!(:klass_hero, [
                           :enrollment,
                           :for_querying_enrollments
                         ])

  @spec execute(binary()) :: [String.t()]
  def execute(program_id) when is_binary(program_id) do
    Logger.debug("[Enrollment.ListEnrolledIdentityIds] Querying",
      program_id: program_id
    )

    @enrollment_repository.list_enrolled_identity_ids(program_id)
  end
end
