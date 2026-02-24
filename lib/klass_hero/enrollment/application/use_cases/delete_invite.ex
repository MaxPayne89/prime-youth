defmodule KlassHero.Enrollment.Application.UseCases.DeleteInvite do
  @moduledoc """
  Deletes a bulk enrollment invite by ID.

  Hard-deletes the staging record. If the invite's email was already
  sent, the link becomes invalid (claim controller returns :not_found).
  """

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])

  @spec execute(binary()) :: :ok | {:error, :not_found | :delete_failed}
  def execute(invite_id) when is_binary(invite_id) do
    @invite_repository.delete(invite_id)
  end
end
