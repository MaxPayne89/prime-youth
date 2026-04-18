defmodule KlassHero.Provider.Application.Queries.ListProgramSessions do
  @moduledoc "Lists per-session detail rows for a provider's program."

  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  @for_querying_session_details Application.compile_env!(
                                  :klass_hero,
                                  [:provider, :for_querying_session_details]
                                )

  @spec run(binary(), binary()) :: [SessionDetail.t()]
  def run(provider_id, program_id), do: @for_querying_session_details.list_by_program(provider_id, program_id)
end
