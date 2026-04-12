defmodule KlassHero.Enrollment.Application.Queries.ListParentEnrollments do
  @moduledoc """
  Use case for listing all enrollments for a parent.
  """

  alias KlassHero.Enrollment.Domain.Models.Enrollment

  require Logger

  @enrollment_repository Application.compile_env!(:klass_hero, [
                           :enrollment,
                           :for_querying_enrollments
                         ])

  @doc """
  Lists all enrollments for the given parent ID.

  Returns list of Enrollment.t(), ordered by enrolled_at descending (most recent first).
  Returns empty list if no enrollments found.
  """
  @spec execute(binary()) :: [Enrollment.t()]
  def execute(parent_id) when is_binary(parent_id) do
    Logger.debug("[Enrollment.ListParentEnrollments] Listing enrollments", parent_id: parent_id)
    @enrollment_repository.list_by_parent(parent_id)
  end
end
