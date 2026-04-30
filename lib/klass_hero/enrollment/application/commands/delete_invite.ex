defmodule KlassHero.Enrollment.Application.Commands.DeleteInvite do
  @moduledoc """
  Deletes a bulk enrollment invite by ID.

  Hard-deletes the staging record. If the invite's email was already
  sent, the link becomes invalid (claim controller returns :not_found).
  """

  alias KlassHero.Enrollment
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.EventDispatchHelper

  @context Enrollment

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
    with {:ok, invite} <- @invite_reader.get_by_id(invite_id),
         :ok <- ensure_owner(invite, provider_id),
         :ok <- @invite_repository.delete(invite_id) do
      dispatch_invite_deleted(invite)
      :ok
    end
  end

  # Returns :not_found (not :forbidden) on mismatch — avoids leaking invite existence.
  defp ensure_owner(%{provider_id: provider_id}, provider_id), do: :ok
  defp ensure_owner(_invite, _provider_id), do: {:error, :not_found}

  defp dispatch_invite_deleted(invite) do
    invite.id
    |> EnrollmentEvents.invite_deleted(%{
      invite_id: invite.id,
      program_id: invite.program_id,
      provider_id: invite.provider_id
    })
    |> EventDispatchHelper.dispatch(@context)
  end
end
