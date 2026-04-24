defmodule KlassHero.Provider.Domain.Ports.ForQueryingSessionDetails do
  @moduledoc """
  Read port for per-session detail rows.

  Implementations query the `provider_session_details` projection table
  (populated by `ProviderSessionDetails` GenServer).
  """

  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  @callback list_by_program(provider_id :: binary(), program_id :: binary()) :: [SessionDetail.t()]

  @callback get_by_id(session_id :: Ecto.UUID.t()) ::
              {:ok, SessionDetail.t()} | {:error, :not_found}
end
