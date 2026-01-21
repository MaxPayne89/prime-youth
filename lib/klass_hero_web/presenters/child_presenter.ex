defmodule KlassHeroWeb.Presenters.ChildPresenter do
  @moduledoc """
  Presentation layer for transforming Child domain models to UI-ready formats.

  This module follows the DDD/Ports & Adapters pattern by keeping presentation
  concerns in the web layer while the domain model stays pure.

  ## Usage

      alias KlassHeroWeb.Presenters.ChildPresenter

      # For simple views (booking dropdown)
      children_for_view = Enum.map(children, &ChildPresenter.to_simple_view/1)

      # For extended views with enrichment data (dashboard cards)
      enrichment = %{sessions: "8/10", progress: 80, activities: ["Art"]}
      children_for_view = Enum.map(children, &ChildPresenter.to_extended_view(&1, enrichment))
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

  When enrichment_data is provided (from Progress Tracking context),
  merges additional fields into the view.

  ## Parameters
    - child: A Child domain model
    - enrichment_data: Optional map with additional data (default: %{})

  ## Example enrichment_data
      %{
        sessions: "8/10",
        progress: 80,
        activities: ["Art", "Chess"]
      }

  Returns a map with: id, name, age, plus any enrichment fields
  """
  def to_extended_view(%Child{} = child, enrichment_data \\ %{}) do
    child
    |> to_simple_view()
    |> Map.merge(enrichment_data)
  end

  @doc """
  Transforms a Child domain model to a profile view format.

  Used for horizontal scrollable profile cards that display child's
  initials in a circular avatar, along with name and age.

  Returns a map with: id, name, age, initials
  """
  def to_profile_view(%Child{} = child) do
    %{
      id: child.id,
      name: Child.full_name(child),
      age: calculate_age(child.date_of_birth),
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
