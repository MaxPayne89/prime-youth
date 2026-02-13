defmodule KlassHero.Enrollment.Application.UseCases.ListEnrolledIdentityIds do
  @moduledoc """
  Use case for listing identity IDs of parents with active enrollments
  in a program.

  Used by the Messaging context to resolve program broadcast recipients
  without directly querying Enrollment schemas.
  """

  require Logger

  @spec execute(binary()) :: [String.t()]
  def execute(program_id) when is_binary(program_id) do
    Logger.debug("[Enrollment.ListEnrolledIdentityIds] Querying",
      program_id: program_id
    )

    repository().list_enrolled_identity_ids(program_id)
  end

  defp repository do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollments]
  end
end
