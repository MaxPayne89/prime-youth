defmodule PrimeYouthWeb.ProgramDetailLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.Live.SampleFixtures
  import PrimeYouthWeb.ReviewComponents

  alias PrimeYouthWeb.Theme

  if Mix.env() == :dev do
    use PrimeYouthWeb.DevAuthToggle
  end

  # Pricing constants
  @default_weeks_count 4

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    # Validate program_id format and fetch program
    with {:ok, id_int} <- parse_program_id(program_id),
         {:ok, program} <- fetch_program(id_int) do
      socket =
        socket
        |> assign(page_title: program.title)
        |> assign(current_user: nil)
        |> assign(program: program)
        |> assign(instructor: sample_instructor())
        |> assign(reviews: sample_reviews())

      {:ok, socket}
    else
      {:error, :invalid_id} ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid program ID")
         |> redirect(to: ~p"/programs")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           "Program not found. It may have been removed or is no longer available."
         )
         |> redirect(to: ~p"/programs")}
    end
  end

  @impl true
  def handle_event("back_to_programs", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs")}
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    # TODO: Implement favorite toggle functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("enroll_now", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs/#{socket.assigns.program.id}/booking")}
  end

  @impl true
  def handle_event("save_for_later", _params, socket) do
    # TODO: Implement save for later functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("ask_questions", _params, socket) do
    # TODO: Open questions/contact modal
    {:noreply, socket}
  end

  # Private helpers - Presentation
  defp format_price(amount), do: "€#{amount}"
  defp format_total_price(weekly_amount), do: "€#{weekly_amount * @default_weeks_count}"

  # Private helpers - Validation
  defp parse_program_id(id_string) do
    case Integer.parse(id_string) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  # Private helpers - Data fetching
  defp fetch_program(id) do
    case get_program_by_id(id) do
      nil -> {:error, :not_found}
      program -> {:ok, program}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen pb-20 md:pb-6", Theme.bg(:muted)]}>
      <!-- Header with Back Button -->
      <div class="relative">
        <!-- Hero Image -->
        <div class={["h-64 relative overflow-hidden", @program.gradient_class]}>
          <div class="absolute inset-0 bg-black/20"></div>
          
    <!-- Back Button -->
          <div class="absolute top-4 left-4 z-10">
            <.back_button phx-click="back_to_programs" />
          </div>
          
    <!-- Favorite Button -->
          <div class="absolute top-4 right-4 z-10">
            <button
              phx-click="toggle_favorite"
              class={[
                "p-2 bg-white/80 backdrop-blur-sm hover:bg-white",
                Theme.transition(:normal),
                Theme.rounded(:full)
              ]}
            >
              <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                <path d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </button>
          </div>
          
    <!-- Program Icon -->
          <div class="absolute inset-0 flex items-center justify-center">
            <div class={[
              "w-24 h-24 bg-white/20 backdrop-blur-sm flex items-center justify-center",
              Theme.rounded(:full)
            ]}>
              <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d={@program.icon_path}
                >
                </path>
              </svg>
            </div>
          </div>
        </div>
        
    <!-- Program Info Overlay -->
        <div class={["absolute bottom-0 left-0 right-0 rounded-t-3xl p-6", Theme.bg(:surface)]}>
          <div class="flex items-start justify-between mb-4">
            <div class="flex-1">
              <h1 class={[Theme.typography(:section_title), "mb-2", Theme.text_color(:heading)]}>
                {@program.title}
              </h1>
              <div class={["flex items-center space-x-4 text-sm mb-2", Theme.text_color(:secondary)]}>
                <span class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                    >
                    </path>
                  </svg>
                  {@program.schedule}
                </span>
                <span class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                    >
                    </path>
                  </svg>
                  Ages {@program.age_range}
                </span>
              </div>
              <div class="flex items-center space-x-2">
                <span
                  :if={@program.spots_left <= 5}
                  class={[
                    "px-2 py-1 text-xs font-medium",
                    Theme.rounded(:full),
                    if(@program.spots_left <= 2,
                      do: "bg-orange-100 text-orange-700",
                      else: "bg-yellow-100 text-yellow-700"
                    )
                  ]}
                >
                  Only {@program.spots_left} spots left!
                </span>
                <span class={[
                  "bg-green-100 text-green-700 px-2 py-1 text-xs font-medium",
                  Theme.rounded(:full)
                ]}>
                  ✓ No hidden fees
                </span>
              </div>
            </div>
            <div class="text-right ml-4">
              <p class={[Theme.typography(:page_title), Theme.text_color(:secondary)]}>
                {format_total_price(@program.price)}
              </p>
              <p class={["text-sm", Theme.text_color(:muted)]}>Total: Sept 1 - Oct 26</p>
              <p class={["text-xs", Theme.text_color(:subtle)]}>
                {format_price(@program.price)}/week • 4 weeks
              </p>
              <p class={["text-xs mt-1", Theme.text_color(:secondary)]}>with {@instructor.name}</p>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Content Area -->
      <div class="mt-20 p-6 max-w-4xl mx-auto">
        <!-- Primary CTA -->
        <div class="mb-6">
          <button
            phx-click="enroll_now"
            class={[
              "w-full text-white py-4 px-6",
              Theme.typography(:card_title),
              Theme.rounded(:lg),
              "hover:shadow-lg transform hover:scale-[1.02]",
              Theme.transition(:normal),
              Theme.gradient(:primary)
            ]}
          >
            Book Now - {format_total_price(@program.price)}
          </button>
          <p class={["text-center text-sm mt-2", Theme.text_color(:secondary)]}>
            <svg
              class="w-4 h-4 inline mr-1"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              >
              </path>
            </svg>
            Free cancellation up to 48 hours before start date
          </p>
        </div>
        
    <!-- Main Content -->
        <div class="space-y-6">
          <!-- Program Description -->
          <div class={[
            Theme.bg(:surface),
            Theme.rounded(:xl),
            "p-6 shadow-sm border",
            Theme.border_color(:light)
          ]}>
            <h3 class={[Theme.typography(:card_title), "mb-3", Theme.text_color(:heading)]}>
              About This Program
            </h3>
            <p class={["leading-relaxed mb-4", Theme.text_color(:secondary)]}>
              {@program.long_description}
            </p>
            
    <!-- What's Included -->
            <div class="space-y-2">
              <h4 class={[Theme.typography(:card_title), Theme.text_color(:heading)]}>
                What's Included:
              </h4>
              <ul class={["space-y-2 text-sm", Theme.text_color(:secondary)]}>
                <li :for={item <- @program.included_items} class="flex items-center">
                  <svg
                    class="w-4 h-4 text-green-500 mr-2 flex-shrink-0"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M5 13l4 4L19 7"
                    >
                    </path>
                  </svg>
                  {item}
                </li>
              </ul>
            </div>
          </div>
          
    <!-- Instructor Info -->
          <div class={[
            Theme.bg(:surface),
            Theme.rounded(:xl),
            "p-6 shadow-sm border",
            Theme.border_color(:light)
          ]}>
            <h3 class={[Theme.typography(:card_title), "mb-4", Theme.text_color(:heading)]}>
              Meet Your Instructor
            </h3>
            <div class="flex items-start space-x-4">
              <img
                src={@instructor.avatar}
                alt="Instructor"
                class={["w-16 h-16", Theme.rounded(:full)]}
              />
              <div class="flex-1">
                <h4 class={[Theme.typography(:card_title), Theme.text_color(:heading)]}>
                  {@instructor.name}
                </h4>
                <p class={["text-sm mb-2", Theme.text_color(:secondary)]}>
                  {@instructor.credentials}
                </p>
                <p class={["text-sm leading-relaxed", Theme.text_color(:secondary)]}>
                  {@instructor.bio}
                </p>
                <div class="flex items-center mt-2">
                  <.star_rating
                    rating={@instructor.rating}
                    size={:medium}
                    show_count
                    count={@instructor.review_count}
                  />
                </div>
              </div>
            </div>
          </div>
          
    <!-- Parent Reviews -->
          <div class={[
            Theme.bg(:surface),
            Theme.rounded(:xl),
            "p-6 shadow-sm border",
            Theme.border_color(:light)
          ]}>
            <h3 class={[Theme.typography(:card_title), "mb-4", Theme.text_color(:heading)]}>
              What Other Parents Say
            </h3>
            <div class="space-y-4">
              <.review_card
                :for={review <- @reviews}
                parent_name={review.parent_name}
                parent_avatar={review.parent_avatar}
                child_name={review.child_name}
                child_age={review.child_age}
                rating={5.0}
                comment={review.comment}
                verified={true}
              />
            </div>

            <div class="text-center mt-4">
              <button class={[
                Theme.text_color(:primary),
                "text-sm font-medium hover:opacity-80 underline"
              ]}>
                View all {@instructor.review_count} reviews
              </button>
            </div>
          </div>
          
    <!-- Bottom CTA -->
          <div class="mt-8">
            <button
              phx-click="enroll_now"
              class={[
                "w-full text-white py-4 px-6",
                Theme.typography(:card_title),
                Theme.rounded(:lg),
                "hover:shadow-lg transform hover:scale-[1.02]",
                Theme.transition(:normal),
                Theme.gradient(:primary)
              ]}
            >
              Enroll Now - {format_total_price(@program.price)}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
