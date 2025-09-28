defmodule PrimeYouthWeb.HomeLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Home")}
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
        <div class="text-center mb-12">
          <h2 class="text-4xl font-bold text-base-content mb-4">What We Offer</h2>
          <p class="text-lg text-base-content/70 max-w-2xl mx-auto">
            Comprehensive programs designed to nurture your child's development through fun, educational activities.
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <!-- Afterschool Programs -->
          <div class="card bg-base-100 shadow-xl border border-base-200 hover:shadow-2xl transition-all duration-300">
            <figure class="px-6 pt-6">
              <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
            </figure>
            <div class="card-body">
              <h3 class="card-title text-primary">Afterschool Programs</h3>
              <p class="text-base-content/70">
                Safe, supervised afterschool activities that combine learning with fun. From homework help to creative projects.
              </p>
              <div class="card-actions justify-end mt-4">
                <a href="#afterschool" class="btn btn-primary btn-sm">Learn More</a>
              </div>
            </div>
          </div>

          <!-- Summer Camps -->
          <div class="card bg-base-100 shadow-xl border border-base-200 hover:shadow-2xl transition-all duration-300">
            <figure class="px-6 pt-6">
              <div class="w-16 h-16 bg-secondary/10 rounded-full flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-secondary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
            </figure>
            <div class="card-body">
              <h3 class="card-title text-secondary">Summer Camps</h3>
              <p class="text-base-content/70">
                Exciting summer adventures with outdoor activities, sports, arts & crafts, and educational field trips.
              </p>
              <div class="card-actions justify-end mt-4">
                <a href="#camps" class="btn btn-secondary btn-sm">Learn More</a>
              </div>
            </div>
          </div>

          <!-- Class Trips -->
          <div class="card bg-base-100 shadow-xl border border-base-200 hover:shadow-2xl transition-all duration-300">
            <figure class="px-6 pt-6">
              <div class="w-16 h-16 bg-accent/10 rounded-full flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </div>
            </figure>
            <div class="card-body">
              <h3 class="card-title text-accent">Class Trips</h3>
              <p class="text-base-content/70">
                Educational excursions to museums, science centers, and cultural sites that bring learning to life.
              </p>
              <div class="card-actions justify-end mt-4">
                <a href="#trips" class="btn btn-accent btn-sm">Learn More</a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Stats Section -->
    <div class="py-16 bg-base-200">
      <div class="container mx-auto px-4">
        <div class="stats stats-vertical lg:stats-horizontal shadow w-full">
          <div class="stat">
            <div class="stat-figure text-primary">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <div class="stat-title">Happy Families</div>
            <div class="stat-value text-primary">500+</div>
            <div class="stat-desc">Families trust us with their children</div>
          </div>

          <div class="stat">
            <div class="stat-figure text-secondary">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <div class="stat-title">Programs</div>
            <div class="stat-value text-secondary">25+</div>
            <div class="stat-desc">Different activity programs</div>
          </div>

          <div class="stat">
            <div class="stat-figure text-accent">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </div>
            <div class="stat-title">Years Experience</div>
            <div class="stat-value text-accent">10+</div>
            <div class="stat-desc">Serving the community</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Call to Action -->
    <div class="py-16 bg-primary text-primary-content">
      <div class="container mx-auto px-4 text-center">
        <h2 class="text-4xl font-bold mb-4">Ready to Get Started?</h2>
        <p class="text-lg opacity-90 mb-8 max-w-2xl mx-auto">
          Join hundreds of families who trust Prime Youth with their children's growth and development.
          Register today and give your child the best afterschool experience.
        </p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <a href="#register" class="btn btn-accent btn-lg">Register Now</a>
          <a href="#contact" class="btn btn-outline btn-lg border-white text-white hover:bg-white hover:text-primary">Contact Us</a>
        </div>
      </div>
    </div>
    """
  end
end