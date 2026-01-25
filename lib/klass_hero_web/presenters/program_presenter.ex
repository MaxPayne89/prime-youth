defmodule KlassHeroWeb.Presenters.ProgramPresenter do
  @moduledoc """
  Presentation layer for transforming Program domain models to UI-ready formats.

  This module follows the DDD/Ports & Adapters pattern by keeping presentation
  concerns in the web layer while the domain model stays pure.

  ## Usage

      alias KlassHeroWeb.Presenters.ProgramPresenter

      # For table views (provider dashboard)
      programs_for_view = Enum.map(programs, &ProgramPresenter.to_table_view/1)
  """

  use Gettext, backend: KlassHeroWeb.Gettext

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @doc """
  Transforms a Program domain model to table view format.

  Used for the provider dashboard program inventory table.

  Returns a map with: id, name, category, price, assigned_staff, status, enrolled, capacity

  ## Placeholder Values

  The following fields return placeholder values pending feature implementation:

  - `assigned_staff: nil` - Staff assignment feature not yet implemented
  - `status: :active` - Program status tracking not yet implemented
  - `enrolled: 0` - Enrollment count integration not yet implemented

  These placeholders ensure the UI can render properly while the underlying
  features are developed in future iterations.
  """
  @spec to_table_view(Program.t()) :: map()
  def to_table_view(%Program{} = program) do
    %{
      id: program.id,
      name: program.title,
      category: humanize_category(program.category),
      price: Decimal.to_integer(program.price),
      # Placeholder: Staff assignment feature pending implementation
      assigned_staff: nil,
      # Placeholder: Program status tracking pending implementation
      status: :active,
      # Placeholder: Enrollment count integration pending implementation
      enrolled: 0,
      capacity: program.spots_available
    }
  end

  @doc """
  Transforms a category code to a human-readable label.
  """
  @spec humanize_category(String.t() | nil) :: String.t()
  def humanize_category(nil), do: "General"
  def humanize_category("arts"), do: gettext("Arts")
  def humanize_category("education"), do: gettext("Education")
  def humanize_category("sports"), do: gettext("Sports")
  def humanize_category("music"), do: gettext("Music")
  def humanize_category(category), do: String.capitalize(category)
end
