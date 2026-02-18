defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingParticipantDetails do
  @moduledoc """
  ACL port for resolving child eligibility data from outside the Enrollment context.

  Enrollment needs date_of_birth, gender, and school_grade to check eligibility
  restrictions when enrolling a child in a program. This port abstracts the
  source of that data (Family context) behind a simple contract.
  """

  @type participant_details :: %{
          date_of_birth: Date.t(),
          gender: String.t(),
          school_grade: non_neg_integer() | nil
        }

  @callback get_participant_details(child_id :: binary()) ::
              {:ok, participant_details()} | {:error, :not_found}
end
