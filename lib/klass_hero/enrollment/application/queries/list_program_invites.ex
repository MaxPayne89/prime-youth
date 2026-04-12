defmodule KlassHero.Enrollment.Application.Queries.ListProgramInvites do
  @moduledoc """
  Fetches all bulk enrollment invites for a program.

  Delegates to the invite repository, ordered by child last name.
  """

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_querying_bulk_enrollment_invites
                     ])

  @spec execute(binary()) :: {:ok, [struct()]}
  def execute(program_id) when is_binary(program_id) do
    {:ok, @invite_repository.list_by_program(program_id)}
  end
end
