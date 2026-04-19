defmodule KlassHero.Provider.Domain.ReadModels.SessionDetail do
  @moduledoc "Display-optimized session detail for the provider dashboard."

  @enforce_keys [:session_id, :program_id, :provider_id, :session_date, :start_time, :end_time, :status]
  defstruct [
    :session_id,
    :program_id,
    :program_title,
    :provider_id,
    :session_date,
    :start_time,
    :end_time,
    :status,
    :current_assigned_staff_id,
    :current_assigned_staff_name,
    :cover_staff_id,
    :cover_staff_name,
    checked_in_count: 0,
    total_count: 0
  ]

  @type status :: :scheduled | :in_progress | :completed | :cancelled

  @type t :: %__MODULE__{
          session_id: binary(),
          program_id: binary(),
          program_title: String.t() | nil,
          provider_id: binary(),
          session_date: Date.t(),
          start_time: Time.t(),
          end_time: Time.t(),
          status: status(),
          current_assigned_staff_id: binary() | nil,
          current_assigned_staff_name: String.t() | nil,
          cover_staff_id: binary() | nil,
          cover_staff_name: String.t() | nil,
          checked_in_count: non_neg_integer(),
          total_count: non_neg_integer()
        }
end
