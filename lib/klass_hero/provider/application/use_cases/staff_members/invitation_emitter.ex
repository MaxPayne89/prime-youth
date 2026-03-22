defmodule KlassHero.Provider.Application.UseCases.StaffMembers.InvitationEmitter do
  @moduledoc """
  Shared helper for emitting `:staff_member_invited` integration events.

  Used by both CreateStaffMember and ResendStaffInvitation use cases.
  """

  alias KlassHero.Provider.Domain.Events.ProviderIntegrationEvents
  alias KlassHero.Shared.IntegrationEventPublishing

  @provider_repository Application.compile_env!(
                         :klass_hero,
                         [:provider, :for_storing_provider_profiles]
                       )

  @spec emit(KlassHero.Provider.Domain.Models.StaffMember.t(), String.t()) ::
          :ok | {:error, term()}
  def emit(staff_member, raw_token) do
    {:ok, provider} = @provider_repository.get(staff_member.provider_id)

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
    |> IntegrationEventPublishing.publish_critical("staff_member_invited",
      staff_member_id: staff_member.id,
      provider_id: staff_member.provider_id
    )
  end
end
