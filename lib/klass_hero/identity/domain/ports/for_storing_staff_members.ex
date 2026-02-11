defmodule KlassHero.Identity.Domain.Ports.ForStoringStaffMembers do
  @moduledoc """
  Repository port for storing and retrieving staff members in the Identity bounded context.

  Defines the contract for staff member persistence.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.Identity.Domain.Models.StaffMember

  @callback create(attrs :: map()) ::
              {:ok, StaffMember.t()} | {:error, term()}

  @callback get(id :: binary()) ::
              {:ok, StaffMember.t()} | {:error, :not_found}

  @callback list_by_provider(provider_id :: binary()) ::
              {:ok, [StaffMember.t()]}

  @callback list_active_by_provider(provider_id :: binary()) ::
              {:ok, [StaffMember.t()]}

  @callback update(staff_member :: StaffMember.t()) ::
              {:ok, StaffMember.t()} | {:error, :not_found | term()}

  @callback delete(id :: binary()) ::
              :ok | {:error, :not_found}
end
