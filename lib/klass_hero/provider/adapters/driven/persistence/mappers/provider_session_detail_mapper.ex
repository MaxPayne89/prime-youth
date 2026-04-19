defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderSessionDetailMapper do
  @moduledoc "Maps between ProviderSessionDetailSchema and the SessionDetail read model."

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  @spec to_read_model(ProviderSessionDetailSchema.t()) :: SessionDetail.t()
  def to_read_model(%ProviderSessionDetailSchema{} = s) do
    %SessionDetail{
      session_id: s.session_id,
      program_id: s.program_id,
      program_title: s.program_title,
      provider_id: s.provider_id,
      session_date: s.session_date,
      start_time: s.start_time,
      end_time: s.end_time,
      status: s.status,
      current_assigned_staff_id: s.current_assigned_staff_id,
      current_assigned_staff_name: s.current_assigned_staff_name,
      cover_staff_id: s.cover_staff_id,
      cover_staff_name: s.cover_staff_name,
      checked_in_count: s.checked_in_count,
      total_count: s.total_count
    }
  end
end
