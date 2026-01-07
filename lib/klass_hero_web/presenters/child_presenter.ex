defmodule KlassHeroWeb.Presenters.ChildPresenter do
  @moduledoc """
  Presentation layer for transforming Child domain models to UI-ready formats.

  This module follows the DDD/Ports & Adapters pattern by keeping presentation
  concerns in the web layer while the domain model stays pure.

  ## Usage

      alias KlassHeroWeb.Presenters.ChildPresenter

      # For simple views (booking dropdown)
      children_for_view = Enum.map(children, &ChildPresenter.to_simple_view/1)

      # For extended views (dashboard cards)
      children_for_view = Enum.map(children, &ChildPresenter.to_extended_view/1)
  """

  alias KlassHero.Identity.Domain.Models.Child

  @doc """
  Transforms a Child domain model to a simple view format.

  Used for contexts where only basic child information is needed,
  such as dropdown selections in booking forms.

  Returns a map with: id, name, age
  """
  def to_simple_view(%Child{} = child) do
    %{
      id: child.id,
      name: Child.full_name(child),
      age: calculate_age(child.date_of_birth)
    }
  end

  @doc """
  Transforms a Child domain model to an extended view format.

  Used for dashboard displays that need additional UI-specific data
  like school, sessions, progress, and activities.

  Returns a map with: id, name, age, school, sessions, progress, activities
  """
  def to_extended_view(%Child{} = child) do
    child
    |> to_simple_view()
    |> Map.merge(ui_enrichment_data(child))
  end

  @doc """
  Transforms a Child domain model to a profile view format.

  Used for horizontal scrollable profile cards that display child's
  initials in a circular avatar, along with name, age, and school.

  Returns a map with: id, name, age, school, initials
  """
  def to_profile_view(%Child{} = child) do
    %{
      id: child.id,
      name: Child.full_name(child),
      age: calculate_age(child.date_of_birth),
      school: "#{child.first_name}'s School",
      initials: extract_initials(Child.full_name(child))
    }
  end

  defp calculate_age(date_of_birth) do
    today = Date.utc_today()
    years = today.year - date_of_birth.year

    if Date.after?(
         Date.new!(today.year, date_of_birth.month, date_of_birth.day),
         today
       ) do
      years - 1
    else
      years
    end
  end

  defp ui_enrichment_data(child) do
    case child.first_name do
      "Emma" ->
        %{
          school: "Greenwood Elementary",
          sessions: "8/10",
          progress: 80,
          activities: ["Art", "Chess", "Swimming"]
        }

      "Liam" ->
        %{
          school: "Sunny Hills Kindergarten",
          sessions: "6/8",
          progress: 75,
          activities: ["Soccer", "Music"]
        }

      _ ->
        %{
          school: "Local School",
          sessions: "0/0",
          progress: 0,
          activities: []
        }
    end
  end

  defp extract_initials(name) when is_binary(name) do
    name
    |> String.split(" ")
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  defp extract_initials(_), do: "?"
end
