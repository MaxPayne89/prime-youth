defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema do
  @moduledoc """
  Read table for the Provider dashboard's per-session view (issue #373).

  Populated by the `ProviderSessionDetails` projection from Participation + Provider
  integration events. Do not write directly — use the projection.
  """

  use Ecto.Schema

  @primary_key {:session_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "provider_session_details" do
    field :program_id, :binary_id
    field :program_title, :string
    field :provider_id, :binary_id

    field :session_date, :date
    field :start_time, :time
    field :end_time, :time
    field :status, Ecto.Enum, values: [:scheduled, :in_progress, :completed, :cancelled]

    field :current_assigned_staff_id, :binary_id
    field :current_assigned_staff_name, :string
    field :cover_staff_id, :binary_id
    field :cover_staff_name, :string

    field :checked_in_count, :integer, default: 0
    field :total_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end
end
