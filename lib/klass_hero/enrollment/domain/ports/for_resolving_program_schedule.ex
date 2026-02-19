defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingProgramSchedule do
  @moduledoc """
  ACL port for resolving program schedule data from outside the Enrollment context.

  Enrollment needs the program start date for "at program start" eligibility checks
  (e.g., verifying a child's age at the time the program begins). This port abstracts
  the source of that data (ProgramCatalog context) behind a simple contract.
  """

  @callback get_program_start_date(program_id :: binary()) ::
              {:ok, Date.t() | nil} | {:error, :not_found}
end
