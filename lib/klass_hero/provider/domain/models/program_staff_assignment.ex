defmodule KlassHero.Provider.Domain.Models.ProgramStaffAssignment do
  @moduledoc """
  Represents an assignment of a staff member to a program.
  An active assignment has `unassigned_at: nil`.
  """

  @enforce_keys [:id, :provider_id, :program_id, :staff_member_id, :assigned_at]

  defstruct [
    :id,
    :provider_id,
    :program_id,
    :staff_member_id,
    :assigned_at,
    :unassigned_at,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          provider_id: String.t(),
          program_id: String.t(),
          staff_member_id: String.t(),
          assigned_at: DateTime.t(),
          unassigned_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{unassigned_at: nil}), do: true
  def active?(%__MODULE__{}), do: false
end
