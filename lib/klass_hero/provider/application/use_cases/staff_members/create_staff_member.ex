defmodule KlassHero.Provider.Application.UseCases.StaffMembers.CreateStaffMember do
  @moduledoc """
  Use case for creating a new staff member.

  Orchestrates domain validation and persistence through the repository port.
  """

  alias KlassHero.Provider.Domain.Models.StaffMember

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  def execute(attrs) when is_map(attrs) do
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated} <- StaffMember.new(attrs_with_id),
         {:ok, persisted} <- @repository.create(attrs_with_id) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
