defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderSessionDetailMapperTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderSessionDetailMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  test "to_read_model/1 maps schema struct to DTO with all fields" do
    schema = %ProviderSessionDetailSchema{
      session_id: "s-1",
      program_id: "p-1",
      program_title: "Judo",
      provider_id: "pr-1",
      session_date: ~D[2026-05-01],
      start_time: ~T[15:00:00],
      end_time: ~T[16:00:00],
      status: :scheduled,
      current_assigned_staff_id: "staff-1",
      current_assigned_staff_name: "Alice",
      cover_staff_id: nil,
      cover_staff_name: nil,
      checked_in_count: 3,
      total_count: 5
    }

    assert %SessionDetail{
             session_id: "s-1",
             program_title: "Judo",
             status: :scheduled,
             current_assigned_staff_name: "Alice",
             checked_in_count: 3,
             total_count: 5
           } = ProviderSessionDetailMapper.to_read_model(schema)
  end
end
