defmodule PrimeYouthWeb.ProgramDetailLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    program = get_program_by_id(program_id)

    socket =
      socket
      |> assign(page_title: program.title)
      |> assign(current_user: nil)
      |> assign(program: program)
      |> assign(instructor: sample_instructor())
      |> assign(reviews: sample_reviews())

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if socket.assigns.current_user, do: nil, else: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
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
    # TODO: Navigate to enrollment page
    {:noreply, socket}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pb-20 md:pb-6">
      <!-- Header with Back Button -->
      <div class="relative">
        <!-- Hero Image -->
        <div class={["h-64 relative overflow-hidden", @program.gradient_class]}>
          <div class="absolute inset-0 bg-black/20"></div>
          
    <!-- Back Button -->
          <div class="absolute top-4 left-4 z-10">
            <button
              phx-click="back_to_programs"
              class="p-2 bg-white/80 backdrop-blur-sm rounded-full hover:bg-white transition-colors"
            >
              <svg class="w-5 h-5 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 19l-7-7 7-7"
                >
                </path>
              </svg>
            </button>
          </div>
          
    <!-- Favorite Button -->
          <div class="absolute top-4 right-4 z-10">
            <button
              phx-click="toggle_favorite"
              class="p-2 bg-white/80 backdrop-blur-sm rounded-full hover:bg-white transition-colors"
            >
              <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                <path d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </button>
          </div>
          
    <!-- Program Icon -->
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="w-24 h-24 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
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
        <div class="absolute bottom-0 left-0 right-0 bg-white rounded-t-3xl p-6">
          <div class="flex items-start justify-between mb-4">
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-gray-900 mb-2">{@program.title}</h1>
              <div class="flex items-center space-x-4 text-sm text-gray-600 mb-2">
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
                    "px-2 py-1 rounded-full text-xs font-medium",
                    if(@program.spots_left <= 2,
                      do: "bg-orange-100 text-orange-700",
                      else: "bg-yellow-100 text-yellow-700"
                    )
                  ]}
                >
                  Only {@program.spots_left} spots left!
                </span>
                <span class="bg-green-100 text-green-700 px-2 py-1 rounded-full text-xs font-medium">
                  ✓ No hidden fees
                </span>
              </div>
            </div>
            <div class="text-right ml-4">
              <p class="text-3xl font-bold text-prime-magenta-400">
                {format_total_price(@program.price)}
              </p>
              <p class="text-sm text-gray-500">Total: Sept 1 - Oct 26</p>
              <p class="text-xs text-gray-400">{format_price(@program.price)}/week • 4 weeks</p>
              <p class="text-xs text-gray-600 mt-1">with {@instructor.name}</p>
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
            class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-4 px-6 rounded-xl font-semibold text-lg hover:shadow-lg transform hover:scale-[1.02] transition-all duration-200"
          >
            Book Now - {format_total_price(@program.price)}
          </button>
          <p class="text-center text-sm text-gray-600 mt-2">
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
          <div class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">About This Program</h3>
            <p class="text-gray-600 leading-relaxed mb-4">
              {@program.long_description}
            </p>
            
    <!-- What's Included -->
            <div class="space-y-2">
              <h4 class="font-semibold text-gray-900">What's Included:</h4>
              <ul class="space-y-2 text-sm text-gray-600">
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
          <div class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Meet Your Instructor</h3>
            <div class="flex items-start space-x-4">
              <img src={@instructor.avatar} alt="Instructor" class="w-16 h-16 rounded-full" />
              <div class="flex-1">
                <h4 class="font-semibold text-gray-900">{@instructor.name}</h4>
                <p class="text-sm text-gray-600 mb-2">{@instructor.credentials}</p>
                <p class="text-sm text-gray-600 leading-relaxed">
                  {@instructor.bio}
                </p>
                <div class="flex items-center mt-2">
                  <div class="flex text-yellow-400">
                    <svg :for={_ <- 1..5} class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                    </svg>
                  </div>
                  <span class="text-sm text-gray-600 ml-2">
                    {@instructor.rating}/5 from {@instructor.review_count} reviews
                  </span>
                </div>
              </div>
            </div>
          </div>


    <!-- Parent Reviews -->
          <div class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">What Other Parents Say</h3>
            <div class="space-y-4">
              <div
                :for={review <- @reviews}
                class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm"
              >
                <div class="flex justify-between items-start mb-3">
                  <div class="flex items-start gap-3">
                    <img
                      src={review.parent_avatar}
                      alt={review.parent_name}
                      class="w-10 h-10 rounded-full"
                    />
                    <div>
                      <div class="font-medium text-gray-900 text-sm">{review.parent_name}</div>
                      <div class="text-xs text-gray-500">
                        Mother of {review.child_name} ({review.child_age}) • <span class="text-green-600">✓ Verified Parent</span>
                      </div>
                    </div>
                  </div>
                  <div class="flex text-yellow-400">
                    <svg :for={_ <- 1..5} class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                    </svg>
                  </div>
                </div>
                <p class="text-gray-600 text-sm leading-relaxed italic">"{review.comment}"</p>
              </div>
            </div>

            <div class="text-center mt-4">
              <button class="text-prime-cyan-400 text-sm font-medium hover:text-prime-cyan-400/80 underline">
                View all {@instructor.review_count} reviews
              </button>
            </div>
          </div>

    <!-- Bottom CTA -->
          <div class="mt-8">
            <button
              phx-click="enroll_now"
              class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-4 px-6 rounded-xl font-semibold text-lg hover:shadow-lg transform hover:scale-[1.02] transition-all duration-200"
            >
              Enroll Now - {format_total_price(@program.price)}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp sample_user do
    %{
      name: "Sarah Johnson",
      email: "sarah.johnson@example.com",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face"
    }
  end

  defp get_program_by_id(id) do
    # For now, return the first sample program - in a real app this would query the database
    programs = sample_programs()
    Enum.find(programs, fn p -> p.id == String.to_integer(id) end) || List.first(programs)
  end

  defp sample_programs do
    [
      %{
        id: 1,
        title: "Creative Art World",
        description:
          "Unleash your child's creativity through painting, drawing, sculpture, and mixed media projects.",
        long_description:
          "Unleash your child's creativity in our comprehensive art program! Students will explore various artistic mediums including painting, drawing, sculpting, and digital art. Our expert instructors guide each child to develop their unique artistic voice while building fundamental skills.",
        gradient_class: "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600",
        icon_path:
          "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v1.5L15 4l2 7-7 2.5V15a2 2 0 01-2 2z",
        schedule: "Wednesdays 4-6 PM",
        age_range: "6-12",
        price: 45,
        spots_left: 2,
        included_items: [
          "Professional art supplies and materials",
          "Small group instruction (max 8 students)",
          "Take-home art portfolio",
          "End-of-session showcase exhibition"
        ]
      },
      %{
        id: 2,
        title: "Chess Masters",
        description:
          "Learn strategic thinking and problem-solving through the ancient game of chess.",
        long_description:
          "Develop strategic thinking and problem-solving skills through the timeless game of chess. Perfect for developing critical thinking skills, patience, and logical reasoning in a fun, supportive environment.",
        gradient_class: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
        icon_path:
          "M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z",
        schedule: "Mon, Wed 4-5 PM",
        age_range: "8-14",
        price: 25,
        spots_left: 5,
        included_items: [
          "Chess set for each student",
          "Beginner to advanced curriculum",
          "Tournament preparation",
          "Chess notation workbook"
        ]
      }
    ]
  end

  defp sample_instructor do
    %{
      name: "Ms. Elena Rodriguez",
      credentials: "Master of Fine Arts, 8+ years teaching experience",
      bio:
        "Elena specializes in fostering creativity while building technical skills. Her students have won numerous local art competitions and developed lifelong passions for the arts.",
      avatar:
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=64&h=64&fit=crop&crop=face",
      rating: "4.9",
      review_count: 47
    }
  end

  defp sample_reviews do
    [
      %{
        comment:
          "My daughter Emma has grown so much in confidence and creativity. She can't wait for art class each week!",
        parent_name: "Sarah Johnson",
        parent_avatar:
          "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=32&h=32&fit=crop&crop=face",
        child_name: "Emma",
        child_age: 8,
        verified: true
      },
      %{
        comment:
          "Excellent program with caring instructors. The small class size makes all the difference.",
        parent_name: "Michael Chen",
        parent_avatar:
          "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=32&h=32&fit=crop&crop=face",
        child_name: "Sophie",
        child_age: 7,
        verified: true
      },
      %{
        comment:
          "As a working parent, I appreciate the reliable schedule and professional communication. Max has made friends and learned techniques I never could have taught him at home.",
        parent_name: "Lisa Rodriguez",
        parent_avatar:
          "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=32&h=32&fit=crop&crop=face",
        child_name: "Max",
        child_age: 9,
        verified: true
      }
    ]
  end

  defp format_price(amount), do: "€#{amount}"
  defp format_total_price(weekly_amount), do: "€#{weekly_amount * 4}"
end
