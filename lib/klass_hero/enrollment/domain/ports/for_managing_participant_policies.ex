defmodule KlassHero.Enrollment.Domain.Ports.ForManagingParticipantPolicies do
  @moduledoc """
  Write-only port for managing participant policies in the Enrollment bounded context.

  Defines the contract for participant policy write operations (CQRS command side).
  Read operations have been moved to `ForQueryingParticipantPolicies`.
  """

  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy

  @doc """
  Creates or updates a participant policy for a program.
  Uses upsert semantics — if a policy already exists for the program_id, it is updated.
  """
  @callback upsert(attrs :: map()) ::
              {:ok, ParticipantPolicy.t()} | {:error, term()}
end
