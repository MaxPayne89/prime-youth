defmodule KlassHeroWeb.AboutLive do
  use KlassHeroWeb, :live_view

  alias KlassHeroWeb.{Theme, UIComponents}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: gettext("About Us"))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen pb-20 md:pb-6", Theme.bg(:muted)]}>
      <%!-- Hero Section --%>
      <div class="bg-hero-black py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 class="font-display text-4xl md:text-5xl lg:text-6xl text-white mb-6">
            {gettext("OUR MISSION")}
          </h1>
          <p class="text-xl text-white/80 max-w-3xl mx-auto">
            {gettext(
              "To modernize how families discover and engage with children's programs in Berlin"
            )}
          </p>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24">
        <%!-- Built for Berlin Families Section --%>
        <div class="grid md:grid-cols-2 gap-8 md:gap-12 items-center">
          <div class="space-y-6">
            <h2 class="font-display text-3xl md:text-4xl text-hero-black">
              {gettext("Built for Berlin Families")}
            </h2>
            <p class="text-lg text-hero-grey-700 leading-relaxed">
              {gettext(
                "We understand the unique needs of Berlin's diverse families. Our platform connects you with vetted, high-quality programs that match your values and your children's interests."
              )}
            </p>
            <p class="text-lg text-hero-grey-700 leading-relaxed">
              {gettext(
                "From sports to arts, technology to languages, we make it easy to discover enriching activities that fit your family's schedule and budget."
              )}
            </p>
          </div>

          <div class="space-y-4">
            <%!-- Safety First --%>
            <div class="border-2 border-hero-blue-400 rounded-lg p-6 bg-white">
              <div class="flex items-start gap-4">
                <div class="flex-shrink-0">
                  <UIComponents.gradient_icon
                    gradient_class="bg-hero-blue-400"
                    size="md"
                    shape="circle"
                  >
                    <.icon name="hero-shield-check" class="w-6 h-6 text-white" />
                  </UIComponents.gradient_icon>
                </div>
                <div>
                  <h3 class="font-semibold text-lg text-hero-black mb-2">
                    {gettext("Safety First")}
                  </h3>
                  <p class="text-hero-grey-700">
                    {gettext("All instructors are background-checked and verified")}
                  </p>
                </div>
              </div>
            </div>

            <%!-- Sustainability --%>
            <div class="border-2 border-green-500 rounded-lg p-6 bg-white">
              <div class="flex items-start gap-4">
                <div class="flex-shrink-0">
                  <UIComponents.gradient_icon gradient_class="bg-green-500" size="md" shape="circle">
                    <.icon name="hero-globe-alt" class="w-6 h-6 text-white" />
                  </UIComponents.gradient_icon>
                </div>
                <div>
                  <h3 class="font-semibold text-lg text-hero-black mb-2">
                    {gettext("Sustainability")}
                  </h3>
                  <p class="text-hero-grey-700">
                    {gettext("Supporting local programs and eco-conscious practices")}
                  </p>
                </div>
              </div>
            </div>

            <%!-- Community --%>
            <div class="border-2 border-hero-yellow-400 rounded-lg p-6 bg-white">
              <div class="flex items-start gap-4">
                <div class="flex-shrink-0">
                  <UIComponents.gradient_icon
                    gradient_class="bg-hero-yellow-400"
                    size="md"
                    shape="circle"
                  >
                    <.icon name="hero-heart" class="w-6 h-6 text-white" />
                  </UIComponents.gradient_icon>
                </div>
                <div>
                  <h3 class="font-semibold text-lg text-hero-black mb-2">
                    {gettext("Community")}
                  </h3>
                  <p class="text-hero-grey-700">
                    {gettext("Building connections between families and local instructors")}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- 4-Step Vetting Process --%>
      <div class="bg-hero-pink-50 py-12 md:py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class="font-display text-3xl md:text-4xl lg:text-5xl text-hero-black mb-4">
              {gettext("Our 4-Step Vetting Process")}
            </h2>
            <p class="text-lg text-hero-grey-700 max-w-3xl mx-auto">
              {gettext(
                "Every instructor goes through rigorous screening to ensure the highest quality"
              )}
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 md:gap-8">
            <%!-- Step 1: Identity Verification --%>
            <div class="bg-white rounded-xl p-6 text-center">
              <div class="w-16 h-16 mx-auto mb-4 bg-blue-200 rounded-full flex items-center justify-center">
                <span class="text-2xl font-bold text-blue-700">1</span>
              </div>
              <div class="mb-4">
                <UIComponents.gradient_icon
                  gradient_class="bg-blue-500"
                  size="md"
                  shape="circle"
                >
                  <.icon name="hero-identification" class="w-6 h-6 text-white" />
                </UIComponents.gradient_icon>
              </div>
              <h3 class="font-semibold text-lg text-hero-black mb-2">
                {gettext("Identity Verification")}
              </h3>
              <p class="text-hero-grey-700">
                {gettext("Official ID and credentials check")}
              </p>
            </div>

            <%!-- Step 2: Background Check --%>
            <div class="bg-white rounded-xl p-6 text-center">
              <div class="w-16 h-16 mx-auto mb-4 bg-purple-200 rounded-full flex items-center justify-center">
                <span class="text-2xl font-bold text-purple-700">2</span>
              </div>
              <div class="mb-4">
                <UIComponents.gradient_icon
                  gradient_class="bg-purple-500"
                  size="md"
                  shape="circle"
                >
                  <.icon name="hero-magnifying-glass-circle" class="w-6 h-6 text-white" />
                </UIComponents.gradient_icon>
              </div>
              <h3 class="font-semibold text-lg text-hero-black mb-2">
                {gettext("Background Check")}
              </h3>
              <p class="text-hero-grey-700">
                {gettext("Comprehensive criminal record screening")}
              </p>
            </div>

            <%!-- Step 3: Qualifications --%>
            <div class="bg-white rounded-xl p-6 text-center">
              <div class="w-16 h-16 mx-auto mb-4 bg-pink-200 rounded-full flex items-center justify-center">
                <span class="text-2xl font-bold text-pink-700">3</span>
              </div>
              <div class="mb-4">
                <UIComponents.gradient_icon
                  gradient_class="bg-pink-500"
                  size="md"
                  shape="circle"
                >
                  <.icon name="hero-academic-cap" class="w-6 h-6 text-white" />
                </UIComponents.gradient_icon>
              </div>
              <h3 class="font-semibold text-lg text-hero-black mb-2">
                {gettext("Qualifications")}
              </h3>
              <p class="text-hero-grey-700">
                {gettext("Certification and experience verification")}
              </p>
            </div>

            <%!-- Step 4: Personal Interview --%>
            <div class="bg-white rounded-xl p-6 text-center">
              <div class="w-16 h-16 mx-auto mb-4 bg-green-200 rounded-full flex items-center justify-center">
                <span class="text-2xl font-bold text-green-700">4</span>
              </div>
              <div class="mb-4">
                <UIComponents.gradient_icon
                  gradient_class="bg-green-500"
                  size="md"
                  shape="circle"
                >
                  <.icon name="hero-video-camera" class="w-6 h-6 text-white" />
                </UIComponents.gradient_icon>
              </div>
              <h3 class="font-semibold text-lg text-hero-black mb-2">
                {gettext("Personal Interview")}
              </h3>
              <p class="text-hero-grey-700">
                {gettext("In-depth conversation about values and approach")}
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Founding Team Section --%>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24">
        <div class="text-center mb-12">
          <h2 class="font-display text-3xl md:text-4xl lg:text-5xl text-hero-black mb-4">
            {gettext("The Founding Team")}
          </h2>
          <p class="text-lg text-hero-grey-700 max-w-3xl mx-auto">
            {gettext("Meet the team building the future of children's programs in Berlin")}
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-12">
          <%!-- Shane Ogilvie - CEO & Co-Founder --%>
          <div class="text-center">
            <div class="w-32 h-32 mx-auto mb-6 bg-hero-blue-400 rounded-full flex items-center justify-center">
              <span class="text-4xl font-bold text-white">SO</span>
            </div>
            <h3 class="font-semibold text-xl text-hero-black mb-1">
              {gettext("Shane Ogilvie")}
            </h3>
            <p class="text-hero-blue-500 font-medium mb-4">
              {gettext("CEO & Co-Founder")}
            </p>
            <p class="text-hero-grey-700">
              {gettext(
                "Former education technology leader with a passion for making quality programs accessible to all families."
              )}
            </p>
          </div>

          <%!-- Max Pergl - CTO & Co-Founder --%>
          <div class="text-center">
            <div class="w-32 h-32 mx-auto mb-6 bg-pink-500 rounded-full flex items-center justify-center">
              <span class="text-4xl font-bold text-white">MP</span>
            </div>
            <h3 class="font-semibold text-xl text-hero-black mb-1">
              {gettext("Max Pergl")}
            </h3>
            <p class="text-pink-500 font-medium mb-4">
              {gettext("CTO & Co-Founder")}
            </p>
            <p class="text-hero-grey-700">
              {gettext(
                "Technology innovator committed to building platforms that empower families and instructors."
              )}
            </p>
          </div>

          <%!-- Konstantin Pergl - CFO & Co-Founder --%>
          <div class="text-center">
            <div class="w-32 h-32 mx-auto mb-6 bg-orange-500 rounded-full flex items-center justify-center">
              <span class="text-4xl font-bold text-white">KP</span>
            </div>
            <h3 class="font-semibold text-xl text-hero-black mb-1">
              {gettext("Konstantin Pergl")}
            </h3>
            <p class="text-orange-500 font-medium mb-4">
              {gettext("CFO & Co-Founder")}
            </p>
            <p class="text-hero-grey-700">
              {gettext(
                "Financial strategist focused on sustainable growth and value creation for all stakeholders."
              )}
            </p>
          </div>
        </div>
      </div>

      <%!-- CTA Section --%>
      <div class="bg-hero-pink-50 py-16 text-center">
        <h2 class="font-display text-3xl md:text-4xl text-hero-black mb-8">
          {gettext("Ready to join the movement?")}
        </h2>
        <.link
          navigate={~p"/users/register"}
          class="inline-block bg-hero-blue-500 hover:bg-hero-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-all duration-200 transform hover:scale-105"
        >
          {gettext("GET STARTED TODAY")}
        </.link>
      </div>
    </div>
    """
  end
end
