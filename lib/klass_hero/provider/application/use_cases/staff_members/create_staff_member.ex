defmodule KlassHero.Provider.Application.UseCases.StaffMembers.CreateStaffMember do
  @moduledoc """
  Use case for creating a new staff member.

  Orchestrates domain validation and persistence through the repository port.

  ## Return values

  - `{:ok, staff_member}` — staff member without email (display-only, no invitation)
  - `{:ok, staff_member, raw_token}` — staff member with email; invitation token generated,
    `:staff_member_invited` integration event emitted
  """

  alias KlassHero.Provider.Domain.Events.ProviderIntegrationEvents
  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Shared.IntegrationEventPublishing

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])
  @provider_repository Application.compile_env!(
                         :klass_hero,
                         [:provider, :for_storing_provider_profiles]
                       )

  def execute(attrs) when is_map(attrs) do
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    if has_email?(attrs_with_id) do
      execute_with_invitation(attrs_with_id)
    else
      execute_display_only(attrs_with_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp has_email?(attrs) do
    case attrs[:email] || attrs["email"] do
      nil -> false
      "" -> false
      email when is_binary(email) -> String.trim(email) != ""
    end
  end

  defp execute_display_only(attrs) do
    with {:ok, _validated} <- StaffMember.new(attrs),
         {:ok, persisted} <- @repository.create(attrs) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end

  defp execute_with_invitation(attrs) do
    raw_bytes = :crypto.strong_rand_bytes(32)
    raw_token = Base.url_encode64(raw_bytes, padding: false)
    token_hash = :crypto.hash(:sha256, raw_bytes)

    attrs_with_invitation =
      attrs
      |> Map.put(:invitation_status, "pending")
      |> Map.put(:invitation_token_hash, token_hash)

    with {:ok, _validated} <- StaffMember.new(attrs_with_invitation),
         {:ok, persisted} <- @repository.create(attrs_with_invitation),
         :ok <- emit_staff_member_invited(persisted, raw_token) do
      {:ok, persisted, raw_token}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end

  defp emit_staff_member_invited(staff_member, raw_token) do
    {:ok, provider_profile} = @provider_repository.get(staff_member.provider_id)

    event =
      ProviderIntegrationEvents.staff_member_invited(
        staff_member.id,
        %{
          provider_id: staff_member.provider_id,
          email: staff_member.email,
          first_name: staff_member.first_name,
          last_name: staff_member.last_name,
          business_name: provider_profile.business_name,
          raw_token: raw_token
        }
      )

    IntegrationEventPublishing.publish_critical(event, "staff_member_invited",
      staff_member_id: staff_member.id,
      provider_id: staff_member.provider_id
    )
  end
end
