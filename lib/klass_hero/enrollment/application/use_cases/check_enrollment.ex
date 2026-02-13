defmodule KlassHero.Enrollment.Application.UseCases.CheckEnrollment do
  @moduledoc """
  Use case for checking if a parent is actively enrolled in a program.

  Used by the Messaging context to verify enrollment status without
  directly querying Enrollment schemas.
  """

  require Logger

  @spec execute(binary(), binary()) :: boolean()
  def execute(program_id, identity_id) when is_binary(program_id) and is_binary(identity_id) do
    Logger.debug("[Enrollment.CheckEnrollment] Checking",
      program_id: program_id,
      identity_id: identity_id
    )

    repository().enrolled?(program_id, identity_id)
  end

  defp repository do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollments]
  end
end
