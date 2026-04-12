defmodule KlassHero.Provider.Application.InvitationEmitter do
  @moduledoc """
  Shared helper for emitting `:staff_member_invited` integration events.

  Used by both CreateStaffMember and ResendStaffInvitation use cases.
  """

  alias KlassHero.Provider.Domain.Events.ProviderIntegrationEvents
  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Shared.IntegrationEventPublishing

  @provider_repository Application.compile_env!(
                         :klass_hero,
                         [:provider, :for_storing_provider_profiles]
                       )

  @doc """
  Emits a `:staff_member_invited` integration event with the invitation payload.

  ## Security note

  The `raw_token` (unhashed invitation secret) is included in the event payload
  so the Accounts handler can construct the invitation URL without cross-context
  knowledge of token storage. This means the raw token is persisted in `oban_jobs`
  JSON until job cleanup. Acceptable because the token expires in 7 days and is
  single-use (only valid when `invitation_status == "sent"`).
  """
  @spec emit(StaffMember.t(), String.t()) ::
          :ok | {:error, term()}
  def emit(staff_member, raw_token) do
    with {:ok, provider} <- @provider_repository.get(staff_member.provider_id) do
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
end
