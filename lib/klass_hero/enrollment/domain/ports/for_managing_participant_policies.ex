defmodule KlassHero.Enrollment.Domain.Ports.ForManagingParticipantPolicies do
  @moduledoc """
  Port defining the contract for participant policy persistence.

  Implementations handle storing and retrieving participant eligibility
  restrictions (age, gender, grade) for programs.
  """

  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy

  @doc """
  Creates or updates a participant policy for a program.
  Uses upsert semantics — if a policy already exists for the program_id, it is updated.
  """
  @callback upsert(attrs :: map()) ::
              {:ok, ParticipantPolicy.t()} | {:error, term()}

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
