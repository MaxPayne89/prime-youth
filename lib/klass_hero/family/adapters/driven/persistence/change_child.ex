defmodule KlassHero.Family.Adapters.Driven.Persistence.ChangeChild do
  @moduledoc """
  Adapter for building child form changesets.

  Converts domain Child structs to persistence schemas and produces changesets
  for LiveView form tracking. Lives in the adapter layer because it depends on
  the Ecto schema (ChildSchema).
  """

  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias KlassHero.Family.Domain.Models.Child

  @doc """
  Returns a changeset for child form tracking.

  Accepts either:
  - A plain map of attributes (for new child forms)
  - A `%Child{}` domain struct (for existing child forms with no changes)
  - A `%Child{}` domain struct and attributes map (for existing child forms with changes)
  """
  def execute(attrs) when is_map(attrs) and not is_struct(attrs) do
    ChildSchema.form_changeset(%ChildSchema{}, attrs)
  end

  def execute(%Child{} = child) do
    child |> child_to_schema() |> ChildSchema.form_changeset(%{})
  end

  def execute(%Child{} = child, attrs) when is_map(attrs) do
    child |> child_to_schema() |> ChildSchema.form_changeset(attrs)
  end

  defp child_to_schema(%Child{} = child) do
    %ChildSchema{
      id: child.id,
      first_name: child.first_name,
      last_name: child.last_name,
      date_of_birth: child.date_of_birth,
      emergency_contact: child.emergency_contact,
      support_needs: child.support_needs,
      allergies: child.allergies,
      school_name: child.school_name
    }
  end
end
