defmodule PrimeYouthWeb.ProgramComponents do
  @moduledoc """
  Program-specific UI components for Prime Youth application.

  This module contains components related to programs, activities,
  pricing, and other domain-specific functionality.
  """
  use Phoenix.Component
  use Gettext, backend: PrimeYouthWeb.Gettext

  alias PrimeYouthWeb.UIComponents

  @doc """
  Renders a program card with image, details, and action buttons.

  ## Examples

      <.program_card
        title="Chess Masters"
        description="Learn strategic thinking through chess"
        image="/images/chess.jpg"
        price="$25"
        period="per session"
        age_range="8-12 years"
        spots_left={5}
        schedule="Mon, Wed 4-5 PM" />

      <.program_card
        program={%{
          title: "Art Adventures",
          description: "Creative art projects and exploration",
          image: "/images/art.jpg",
          price: 30,
          period: "per session",
          age_range: "6-10 years",
          spots_left: 2,
          schedule: "Tue, Thu 3:30-4:30 PM"
        }}
        on_favorite="toggle_favorite"
        class="mb-4" />
  """
  attr :program, :map, default: nil, doc: "Program data map (alternative to individual attrs)"
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :image, :string, default: nil
  attr :price, :any, default: nil
  attr :period, :string, default: "per session"
  attr :age_range, :string, default: nil
  attr :spots_left, :integer, default: nil
  attr :schedule, :string, default: nil
  attr :on_favorite, :string, default: nil, doc: "Phoenix event for favorite toggle"
  attr :on_click, :string, default: nil, doc: "Phoenix event for card click"
  attr :class, :string, default: ""

  def program_card(assigns) do
    # Normalize data from program map or individual attributes
    assigns =
      if assigns.program do
        assigns
        |> assign(:title, assigns.program.title || assigns.title)
        |> assign(:description, assigns.program.description || assigns.description)
        |> assign(:image, assigns.program.image || assigns.image)
        |> assign(:price, assigns.program.price || assigns.price)
        |> assign(:period, assigns.program.period || assigns.period)
        |> assign(:age_range, assigns.program.age_range || assigns.age_range)
        |> assign(:spots_left, assigns.program.spots_left || assigns.spots_left)
        |> assign(:schedule, assigns.program.schedule || assigns.schedule)
      else
        assigns
      end

    ~H"""
    <div class={[
      "card bg-base-100 shadow-xl border border-base-200 hover:shadow-2xl transition-all duration-300",
      @class
    ]}>
      <!-- Program Image -->
      <figure class="relative">
        <div class="w-full h-48 bg-base-200 flex items-center justify-center overflow-hidden">
          <div :if={@image} class="w-full h-full">
            <img src={@image} alt={@title} class="w-full h-full object-cover" />
          </div>
          <div :if={!@image} class="text-base-content/40">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-16 w-16"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </div>
        </div>
        
    <!-- Favorite Button -->
        <div :if={@on_favorite} class="absolute top-4 right-4">
          <button
            phx-click={@on_favorite}
            phx-value-program={@title}
            class="btn btn-circle btn-sm bg-white/80 border-none hover:bg-white"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
              />
            </svg>
          </button>
        </div>
        
    <!-- Spots Left Badge -->
        <div :if={@spots_left} class="absolute bottom-4 left-4">
          <UIComponents.status_badge variant={spots_variant(@spots_left)}>
            {@spots_left} spots left
          </UIComponents.status_badge>
        </div>
      </figure>
      
    <!-- Card Body -->
      <div class="card-body">
        <h3 class="card-title text-primary">{@title}</h3>
        <p :if={@description} class="text-base-content/70 text-sm">
          {@description}
        </p>
        
    <!-- Program Details -->
        <div class="space-y-2 my-4">
          <div :if={@age_range} class="flex items-center text-sm text-base-content/60">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 mr-2"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
              />
            </svg>
            Ages {@age_range}
          </div>

          <div :if={@schedule} class="flex items-center text-sm text-base-content/60">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 mr-2"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            {@schedule}
          </div>
        </div>
        
    <!-- Card Actions -->
        <div class="card-actions justify-between items-center mt-4">
          <.price_display :if={@price} amount={@price} period={@period} />

          <button
            :if={@on_click}
            phx-click={@on_click}
            phx-value-program={@title}
            class="btn btn-primary btn-sm"
          >
            Learn More
          </button>
          <a
            :if={!@on_click}
            href="#"
            class="btn btn-primary btn-sm"
          >
            Learn More
          </a>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to determine badge variant based on spots left
  defp spots_variant(spots) when spots <= 2, do: "error"
  defp spots_variant(spots) when spots <= 5, do: "warning"
  defp spots_variant(_), do: "success"

  @doc """
  Renders a formatted price display with amount and period.

  ## Examples

      <.price_display amount={25} period="per session" />

      <.price_display amount="$30" period="per week" class="text-lg" />

      <.price_display amount={0} period="Free" />
  """
  attr :amount, :any, required: true
  attr :period, :string, default: ""
  attr :class, :string, default: ""

  def price_display(assigns) do
    ~H"""
    <div class={["text-right", @class]}>
      <div class="text-lg font-bold text-primary">
        {format_price(@amount)}
      </div>
      <div :if={@period != ""} class="text-sm text-base-content/60">
        {@period}
      </div>
    </div>
    """
  end

  # Helper function to format price
  defp format_price(0), do: "Free"
  defp format_price(amount) when is_integer(amount), do: "$#{amount}"

  defp format_price(amount) when is_float(amount),
    do: "$#{:erlang.float_to_binary(amount, decimals: 2)}"

  defp format_price(amount) when is_binary(amount) do
    if String.starts_with?(amount, "$"), do: amount, else: "$#{amount}"
  end

  defp format_price(amount), do: "#{amount}"
end
