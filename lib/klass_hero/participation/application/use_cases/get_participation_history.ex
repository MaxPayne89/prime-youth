defmodule KlassHero.Participation.Application.UseCases.GetParticipationHistory do
  @moduledoc """
  Use case for retrieving participation history.

  Supports fetching records for a single child or multiple children,
  optionally filtered by date range.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  @type single_child_params :: %{
          required(:child_id) => String.t(),
          optional(:start_date) => Date.t(),
          optional(:end_date) => Date.t()
        }

  @type multiple_children_params :: %{
          required(:child_ids) => [String.t()],
          optional(:start_date) => Date.t(),
          optional(:end_date) => Date.t()
        }

  @type params :: single_child_params() | multiple_children_params()
  @type result :: {:ok, [ParticipationRecord.t()]}

  @doc """
  Retrieves participation history for one or more children.

  ## Parameters

  - `params` - Map containing either:
    - `child_id` - ID of a single child
    - `child_ids` - List of child IDs for fetching multiple children's history
    - `start_date` - Optional start of date range
    - `end_date` - Optional end of date range

  ## Returns

  `{:ok, records}` - List of participation records, ordered by date descending.
  """
  @spec execute(params()) :: result()
  def execute(%{child_ids: child_ids} = params) when is_list(child_ids) do
    start_date = Map.get(params, :start_date)
    end_date = Map.get(params, :end_date)

    records =
      if start_date && end_date do
        participation_repository().list_by_children_and_date_range(
          child_ids,
          start_date,
          end_date
        )
      else
        participation_repository().list_by_children(child_ids)
      end

    {:ok, records}
  end

  def execute(%{child_id: child_id} = params) do
    start_date = Map.get(params, :start_date)
    end_date = Map.get(params, :end_date)

    records =
      if start_date && end_date do
        participation_repository().list_by_child_and_date_range(child_id, start_date, end_date)
      else
        participation_repository().list_by_child(child_id)
      end

    {:ok, records}
  end

  defp participation_repository do
    Application.get_env(:klass_hero, :participation)[:participation_repository]
  end
end
