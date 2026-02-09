defmodule KlassHero.Identity.Application.UseCases.StaffMembers.UpdateStaffMember do
  @moduledoc """
  Use case for updating an existing staff member.

  Loads the staff member, merges updated fields, validates, then persists.
  """

  alias KlassHero.Identity.Domain.Models.StaffMember

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_staff_members])

  @allowed_fields ~w(first_name last_name role email bio headshot_url tags qualifications active)a

  def execute(staff_id, attrs) when is_binary(staff_id) and is_map(attrs) do
    attrs = Map.take(attrs, @allowed_fields)

    with {:ok, existing} <- @repository.get(staff_id),
         merged = Map.merge(Map.from_struct(existing), attrs),
         {:ok, _validated} <- StaffMember.new(merged),
         # Trigger: domain validation passed
         # Why: update existing struct to preserve timestamps
         # Outcome: persistence layer manages updated_at
         updated = struct(existing, attrs),
         {:ok, persisted} <- @repository.update(updated) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
