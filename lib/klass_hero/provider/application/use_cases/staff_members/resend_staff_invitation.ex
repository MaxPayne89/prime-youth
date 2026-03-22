defmodule KlassHero.Provider.Application.UseCases.StaffMembers.ResendStaffInvitation do
  @moduledoc """
  Use case for resending a staff invitation.

  Transitions invitation_status back to :pending, generates a fresh token,
  and re-emits :staff_member_invited to restart the invitation saga.

  Only allowed for staff members in :failed or :expired status.
  """

  alias KlassHero.Provider.Domain.Events.ProviderIntegrationEvents
  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Shared.IntegrationEventPublishing

  @staff_repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])
  @provider_repository Application.compile_env!(:klass_hero, [
                         :provider,
                         :for_storing_provider_profiles
                       ])

  @spec execute(String.t()) ::
          {:ok, StaffMember.t(), String.t()}
          | {:error, :not_found | :invalid_invitation_transition}
  def execute(staff_member_id) when is_binary(staff_member_id) do
    with {:ok, staff} <- @staff_repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, :pending) do
      raw_bytes = :crypto.strong_rand_bytes(32)
      raw_token = Base.url_encode64(raw_bytes, padding: false)
      token_hash = :crypto.hash(:sha256, raw_bytes)

      updated = %{transitioned | invitation_token_hash: token_hash}

      with {:ok, persisted} <- @staff_repository.update(updated),
           :ok <- emit_staff_member_invited(persisted, raw_token) do
        {:ok, persisted, raw_token}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp emit_staff_member_invited(staff_member, raw_token) do
    {:ok, provider} = @provider_repository.get(staff_member.provider_id)

    event =
      ProviderIntegrationEvents.staff_member_invited(
        staff_member.id,
        %{
          provider_id: staff_member.provider_id,
          email: staff_member.email,
          first_name: staff_member.first_name,
          last_name: staff_member.last_name,
          business_name: provider.business_name,
          raw_token: raw_token
        }
      )

    IntegrationEventPublishing.publish_critical(event, "staff_member_invited",
      staff_member_id: staff_member.id,
      provider_id: staff_member.provider_id
    )
  end
end
