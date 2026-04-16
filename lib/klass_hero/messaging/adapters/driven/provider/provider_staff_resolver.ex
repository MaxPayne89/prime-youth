defmodule KlassHero.Messaging.Adapters.Driven.Provider.ProviderStaffResolver do
  @moduledoc """
  Adapter for resolving provider-staff relationships in the Messaging context.

  Delegates to the Provider facade to respect bounded context boundaries —
  Messaging is not allowed to query Provider schemas directly.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForResolvingProviderStaff

  use KlassHero.Shared.Tracing

  @impl true
  @spec active_staff_for_provider?(String.t(), String.t()) :: boolean()
  def active_staff_for_provider?(provider_id, user_id) do
    span do
      set_attributes("acl",
        source: "messaging",
        target: "provider",
        operation: "active_staff_for_provider?"
      )

      case KlassHero.Provider.get_active_staff_member_by_user(user_id) do
        {:ok, %{provider_id: ^provider_id}} -> true
        _ -> false
      end
    end
  end
end
