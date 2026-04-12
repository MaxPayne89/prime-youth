defmodule KlassHero.Enrollment.Domain.Ports.ForQueryingParticipantPolicies do
  @moduledoc """
  Read-only port for querying participant policies in the Enrollment bounded context.

  Defines the contract for participant policy read operations (CQRS query side).
  Write operations remain in `ForManagingParticipantPolicies`.
  """

  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy

  @doc """
  Retrieves the participant policy for a program.
  """
  @callback get_by_program_id(program_id :: binary()) ::
              {:ok, ParticipantPolicy.t()} | {:error, :not_found}

  @doc """
  Retrieves participant policies for multiple programs in a single batch query.

  Returns a map of `program_id => ParticipantPolicy.t()`.
  Programs without a policy are not included in the result.
  """
  @callback get_policies_by_program_ids(program_ids :: [binary()]) ::
              %{binary() => ParticipantPolicy.t()}
end
