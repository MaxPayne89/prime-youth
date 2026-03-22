defmodule KlassHero.Provider.Application.UseCases.StaffMembers.CreateStaffMember do
  @moduledoc """
  Use case for creating a new staff member.

  Orchestrates domain validation and persistence through the repository port.

  ## Return values

  - `{:ok, staff_member}` — staff member without email (display-only, no invitation)
  - `{:ok, staff_member, raw_token}` — staff member with email; invitation token generated,
    `:staff_member_invited` integration event emitted
  """

  alias KlassHero.Provider.Application.UseCases.StaffMembers.InvitationEmitter
  alias KlassHero.Provider.Domain.Models.StaffMember

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

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
    {raw_token, token_hash} = StaffMember.generate_invitation_token()

    attrs_with_invitation =
      attrs
      |> Map.put(:invitation_status, "pending")
      |> Map.put(:invitation_token_hash, token_hash)

    with {:ok, _validated} <- StaffMember.new(attrs_with_invitation),
         {:ok, persisted} <- @repository.create(attrs_with_invitation),
         :ok <- InvitationEmitter.emit(persisted, raw_token) do
      {:ok, persisted, raw_token}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
