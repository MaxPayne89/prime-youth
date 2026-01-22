defmodule KlassHero.Enrollment.Application.UseCases.GetEnrollment do
  @moduledoc """
  Use case for retrieving an enrollment by ID.
  """

  alias KlassHero.Enrollment.Domain.Models.Enrollment

  require Logger

  @doc """
  Retrieves an enrollment by its ID.

  Returns:
  - `{:ok, Enrollment.t()}` when found
  - `{:error, :not_found}` when no enrollment exists with the given ID
  """
  @spec execute(binary()) :: {:ok, Enrollment.t()} | {:error, :not_found}
  def execute(id) when is_binary(id) do
    Logger.debug("[Enrollment.GetEnrollment] Fetching enrollment", enrollment_id: id)
    repository().get_by_id(id)
  end

  defp repository do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollments]
  end
end
