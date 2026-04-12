defmodule KlassHero.Enrollment.Application.Queries.CountProgramInvites do
  @moduledoc """
  Query for counting bulk enrollment invites for a program.
  """

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_querying_bulk_enrollment_invites
                     ])

  @doc """
  Returns the count of bulk enrollment invites for a program.
  """
  @spec execute(binary()) :: non_neg_integer()
  def execute(program_id) when is_binary(program_id) do
    @invite_repository.count_by_program(program_id)
  end
end
