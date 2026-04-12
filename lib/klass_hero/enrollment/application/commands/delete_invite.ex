defmodule KlassHero.Enrollment.Application.Commands.DeleteInvite do
  @moduledoc """
  Deletes a bulk enrollment invite by ID.

  Hard-deletes the staging record. If the invite's email was already
  sent, the link becomes invalid (claim controller returns :not_found).
  """

  @invite_reader Application.compile_env!(:klass_hero, [
                   :enrollment,
                   :for_querying_bulk_enrollment_invites
                 ])
  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])

  @spec execute(binary(), binary()) :: :ok | {:error, :not_found | :delete_failed}
  def execute(invite_id, provider_id) when is_binary(invite_id) and is_binary(provider_id) do
    # Trigger: invite_id comes from untrusted client params
    # Why: without ownership check, any provider could delete another's invite
    # Outcome: verify provider_id matches before deleting; return :not_found on mismatch
    case @invite_reader.get_by_id(invite_id) do
      nil ->
        {:error, :not_found}

      invite when invite.provider_id == provider_id ->
        @invite_repository.delete(invite_id)

      _invite ->
        {:error, :not_found}
    end
  end
end
