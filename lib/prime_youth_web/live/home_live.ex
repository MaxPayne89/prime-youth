defmodule PrimeYouthWeb.HomeLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouthWeb.UIComponents
  alias PrimeYouthWeb.ProgramComponents
  alias PrimeYouthWeb.LayoutComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Home")
      |> assign(programs: sample_programs())
      |> assign(stats: sample_stats())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Hero Section -->
    <div class="hero min-h-screen" style="background: linear-gradient(135deg, theme(colors.primary) 0%, theme(colors.secondary) 50%, theme(colors.accent) 100%);">
      <div class="hero-content text-center text-white">
        <div class="max-w-md">
          <h1 class="mb-5 text-5xl font-bold animate-fade-in">Prime Youth</h1>
          <p class="mb-5 text-lg opacity-90">
            Empowering children through engaging afterschool activities, summer camps, and educational programs that inspire growth and creativity.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <a href="#programs" class="btn btn-accent btn-lg">Explore Programs</a>
            <a href="#contact" class="btn btn-outline btn-lg text-white border-white hover:bg-white hover:text-primary">Get Started</a>
          </div>
        </div>
      </div>
    </div>

    <!-- Features Section -->
    <div class="py-16 bg-base-100">
      <div class="container mx-auto px-4">
        <LayoutComponents.section_header
          title="What We Offer"
          description="Comprehensive programs designed to nurture your child's development through fun, educational activities."
          centered={true}
          class="mb-12"
        />

        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <ProgramComponents.program_card
            :for={program <- @programs}
            program={program}
          />
        </div>
      </div>
    </div>

    <!-- Stats Section -->
    <div class="py-16 bg-base-200">
      <div class="container mx-auto px-4">
        <div class="stats stats-vertical lg:stats-horizontal shadow w-full">
          <UIComponents.stat_card
            :for={stat <- @stats}
            icon={stat.icon}
            title={stat.title}
            value={stat.value}
            description={stat.description}
            color={stat.color}
          />
        </div>
      </div>
    </div>

    <!-- Call to Action -->
    <div class="py-16 bg-primary text-primary-content">
      <div class="container mx-auto px-4 text-center">
        <LayoutComponents.section_header
          title="Ready to Get Started?"
          description="Join hundreds of families who trust Prime Youth with their children's growth and development. Register today and give your child the best afterschool experience."
          centered={true}
          class="mb-8 text-white [&_h2]:text-white [&_p]:text-white/90"
        />
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <a href="#register" class="btn btn-accent btn-lg">Register Now</a>
          <a href="#contact" class="btn btn-outline btn-lg border-white text-white hover:bg-white hover:text-primary">Contact Us</a>
        </div>
      </div>
    </div>
    """
  end

  # Sample data functions
  defp sample_programs do
    [
      %{
        title: "Chess Masters",
        description: "Learn strategic thinking and problem-solving through the ancient game of chess. Perfect for developing critical thinking skills.",
        image: nil,
        price: 25,
        period: "per session",
        age_range: "8-12 years",
        spots_left: 5,
        schedule: "Mon, Wed 4-5 PM"
      },
      %{
        title: "Art Adventures",
        description: "Creative art projects and exploration. From painting to sculpture, unleash your child's artistic potential.",
        image: nil,
        price: 30,
        period: "per session",
        age_range: "6-10 years",
        spots_left: 2,
        schedule: "Tue, Thu 3:30-4:30 PM"
      },
      %{
        title: "Science Explorers",
        description: "Hands-on science experiments and discovery. Making learning fun through interactive activities.",
        image: nil,
        price: 35,
        period: "per session",
        age_range: "7-11 years",
        spots_left: 8,
        schedule: "Fri 4-5:30 PM"
      }
    ]
  end

  defp sample_stats do
    [
      %{
        icon: "hero-users",
        title: "Happy Families",
        value: "500+",
        description: "Families trust us with their children",
        color: "primary"
      },
      %{
        icon: "hero-academic-cap",
        title: "Programs",
        value: "25+",
        description: "Different activity programs",
        color: "secondary"
      },
      %{
        icon: "hero-star",
        title: "Rating",
        value: "4.9/5",
        description: "Average parent satisfaction",
        color: "accent"
      },
      %{
        icon: "hero-clock",
        title: "Experience",
        value: "10+",
        description: "Years serving the community",
        color: "primary"
      }
    ]
  end
end