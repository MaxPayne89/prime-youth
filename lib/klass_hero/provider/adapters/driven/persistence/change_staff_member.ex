defmodule KlassHero.Provider.Adapters.Driven.Persistence.ChangeStaffMember do
  @moduledoc """
  Adapter for building staff member form changesets.

  Converts domain StaffMember structs to persistence schemas and produces
  changesets for LiveView form tracking.
  """

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Provider.Domain.Models.StaffMember

  def execute(%StaffMember{} = staff, attrs \\ %{}) do
    staff |> staff_to_schema() |> StaffMemberSchema.edit_changeset(attrs)
  end

  @doc """
  Returns an empty changeset for creating a new staff member form.
  """
  def new_changeset(attrs \\ %{}) do
    %StaffMemberSchema{} |> StaffMemberSchema.edit_changeset(attrs)
  end

  defp staff_to_schema(%StaffMember{} = staff) do
    # Flatten pay_rate so the form renders current values. Without this the Edit
    # form always shows "None" and a no-touch save would wipe the persisted rate.
    {rate_type, rate_amount, rate_currency} =
      case staff.pay_rate do
        nil -> {nil, nil, nil}
        %{type: type, money: %{amount: amount, currency: currency}} -> {type, amount, currency}
      end

    %StaffMemberSchema{
      id: staff.id,
      provider_id: staff.provider_id,
      first_name: staff.first_name,
      last_name: staff.last_name,
      role: staff.role,
      email: staff.email,
      bio: staff.bio,
      headshot_url: staff.headshot_url,
      tags: staff.tags,
      qualifications: staff.qualifications,
      active: staff.active,
      rate_type: rate_type,
      rate_amount: rate_amount,
      rate_currency: rate_currency
    }
  end
end
