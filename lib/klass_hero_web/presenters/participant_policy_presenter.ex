defmodule KlassHeroWeb.Presenters.ParticipantPolicyPresenter do
  @moduledoc """
  Transforms a participant policy into a view-ready map.

  Keeps the web layer decoupled from domain structs by extracting
  only the fields needed for template rendering.
  """

  @view_fields ~w(min_age_months max_age_months allowed_genders min_grade max_grade eligibility_at)a

  @doc """
  Converts a participant policy to a view map.

  Accepts any map or struct with participant policy fields.
  Returns a plain map with only the fields used by the restriction_info component.
  """
  @spec to_view(map()) :: map()
  def to_view(policy) do
    Map.take(policy, @view_fields)
  end
end
