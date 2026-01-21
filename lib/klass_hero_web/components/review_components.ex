defmodule KlassHeroWeb.ReviewComponents do
  @moduledoc """
  Provides review and rating UI components for Klass Hero application.

  This module contains components related to reviews, ratings, and feedback display.
  """
  use Phoenix.Component

  import KlassHeroWeb.UIComponents

  alias KlassHeroWeb.Theme

  @doc """
  Renders a star rating display.

  Supports three sizes: small, medium, and large.
  Can display full ratings (5 stars) or partial ratings.

  ## Examples

      <.star_rating rating={4.5} size={:medium} />
      <.star_rating rating={5} size={:small} show_count count={42} />
  """
  attr :rating, :float, default: 5.0, doc: "Rating value (0-5)"
  attr :size, :atom, default: :medium, values: [:small, :medium, :large]
  attr :show_count, :boolean, default: false
  attr :count, :integer, default: 0
  attr :class, :string, default: ""

  def star_rating(assigns) do
    rating = parse_rating(assigns.rating)
    full_stars = floor(rating)
    has_half_star = rating - full_stars >= 0.5
    empty_stars = 5 - full_stars - if(has_half_star, do: 1, else: 0)

    assigns =
      assigns
      |> assign(:full_stars, full_stars)
      |> assign(:has_half_star, has_half_star)
      |> assign(:empty_stars, empty_stars)

    ~H"""
    <div class={["flex items-center gap-1", @class]}>
      <div class={["flex", star_size(@size)]}>
        <%!-- Full stars --%>
        <svg
          :for={_ <- 1..max(@full_stars, 0)//1}
          class="w-full h-full text-hero-yellow-400"
          fill="currentColor"
          viewBox="0 0 24 24"
        >
          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
        </svg>
        <%!-- Half star --%>
        <svg
          :if={@has_half_star}
          class="w-full h-full text-hero-yellow-400"
          viewBox="0 0 24 24"
        >
          <defs>
            <linearGradient id="half-star-gradient">
              <stop offset="50%" stop-color="currentColor" />
              <stop offset="50%" stop-color="#E5E7EB" />
            </linearGradient>
          </defs>
          <path
            fill="url(#half-star-gradient)"
            d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"
          />
        </svg>
        <%!-- Empty stars --%>
        <svg
          :for={_ <- 1..max(@empty_stars, 0)//1}
          class="w-full h-full text-hero-grey-300"
          fill="currentColor"
          viewBox="0 0 24 24"
        >
          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
        </svg>
      </div>
      <span :if={@show_count} class={["text-sm ml-1", Theme.text_color(:secondary)]}>
        ({@count} {if @count == 1, do: "review", else: "reviews"})
      </span>
    </div>
    """
  end

  defp star_size(:small), do: "w-3 h-3"
  defp star_size(:medium), do: "w-4 h-4"
  defp star_size(:large), do: "w-5 h-5"

  defp parse_rating(rating) when is_float(rating), do: rating
  defp parse_rating(rating) when is_integer(rating), do: rating / 1
  defp parse_rating(rating) when is_binary(rating), do: String.to_float(rating)

  @doc """
  Renders a review card with avatar, name, rating, and comment.

  ## Examples

      <.review_card
        parent_name="Sarah Johnson"
        child_name="Emma"
        child_age={8}
        rating={5}
        comment="Amazing program! My daughter loves it."
        verified={true}
      />
  """
  attr :parent_name, :string, required: true
  attr :child_name, :string, required: true
  attr :child_age, :integer, required: true
  attr :rating, :float, default: 5.0
  attr :comment, :string, required: true
  attr :verified, :boolean, default: false
  attr :class, :string, default: ""

  def review_card(assigns) do
    ~H"""
    <.card padding="p-4" class={@class}>
      <:body>
        <div class="flex justify-between items-start mb-3">
          <div class="flex items-start gap-3">
            <.user_avatar size="sm" />
            <div>
              <div class={["font-medium text-sm", Theme.text_color(:heading)]}>{@parent_name}</div>
              <div class={["text-xs", Theme.text_color(:muted)]}>
                Mother of {@child_name} ({@child_age})
                <span :if={@verified} class="text-green-600">"  Verified Parent</span>
              </div>
            </div>
          </div>
          <.star_rating rating={@rating} size={:small} />
        </div>
        <p class={["text-sm leading-relaxed italic", Theme.text_color(:secondary)]}>"{@comment}"</p>
      </:body>
    </.card>
    """
  end

  @doc """
  Renders an aggregated rating summary with rating value and total count.

  ## Examples

      <.rating_summary
        rating={4.8}
        total_reviews={156}
      />
  """
  attr :rating, :float, required: true
  attr :total_reviews, :integer, required: true
  attr :class, :string, default: ""

  def rating_summary(assigns) do
    ~H"""
    <div class={["flex items-center gap-2", @class]}>
      <.star_rating rating={@rating} size={:medium} />
      <span class={["text-sm font-medium", Theme.text_color(:heading)]}>
        {format_rating(@rating)}
      </span>
      <span class={["text-sm", Theme.text_color(:muted)]}>({@total_reviews})</span>
    </div>
    """
  end

  defp format_rating(rating) when is_float(rating) do
    :erlang.float_to_binary(rating, decimals: 1)
  end

  defp format_rating(rating) when is_integer(rating), do: "#{rating}.0"
end
