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

  defp vetting_steps do
    [
      %{
        number: 1,
        number_bg: "bg-hero-blue-100",
        number_color: "text-hero-blue-700",
        icon: "hero-identification",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Identity Verification"),
        description: gettext("Official ID and credentials check")
      },
      %{
        number: 2,
        number_bg: "bg-hero-blue-100",
        number_color: "text-hero-blue-700",
        icon: "hero-academic-cap",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Qualifications"),
        description: gettext("Certification and experience verification")
      },
      %{
        number: 3,
        number_bg: "bg-hero-blue-100",
        number_color: "text-hero-blue-700",
        icon: "hero-video-camera",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Personal Interview"),
        description: gettext("In-depth conversation about values and approach")
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen pb-20 md:pb-6", Theme.bg(:muted)]}>
      <%!-- Hero Section --%>
      <div class="bg-hero-pink-50 py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 class="font-display text-4xl md:text-5xl lg:text-6xl text-hero-black mb-6">
            {gettext("OUR MISSION")}
          </h1>
          <p class="text-xl text-hero-grey-600 max-w-3xl mx-auto">
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
            <p class="text-lg text-hero-grey-700 leading-relaxed font-medium">
              {gettext(
                "We are Klass Hero — parents, brothers, and partners of educators — building the infrastructure that helps every child learn and thrive."
              )}
            </p>
          </div>

          <div class="space-y-4">
            <%!-- Safety First --%>
            <div class="border-2 border-hero-yellow-400 rounded-lg p-6 bg-white">
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
            <div class="border-2 border-hero-yellow-400 rounded-lg p-6 bg-white">
              <div class="flex items-start gap-4">
                <div class="flex-shrink-0">
                  <UIComponents.gradient_icon
                    gradient_class="bg-hero-blue-400"
                    size="md"
                    shape="circle"
                  >
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
                    gradient_class="bg-hero-blue-400"
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

      <%!-- 3-Step Vetting Process --%>
      <div class="bg-hero-pink-50 py-12 md:py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class="font-display text-3xl md:text-4xl lg:text-5xl text-hero-black mb-4">
              {gettext("Our 3-Step Vetting Process")}
            </h2>
            <p class="text-lg text-hero-grey-700 max-w-3xl mx-auto">
              {gettext(
                "Every instructor goes through rigorous screening to ensure the highest quality"
              )}
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8">
            <div :for={step <- vetting_steps()} class="bg-white rounded-xl p-6 text-center">
              <div class={[
                "w-16 h-16 mx-auto mb-4 rounded-full flex items-center justify-center",
                step.number_bg
              ]}>
                <span class={["text-2xl font-bold", step.number_color]}>{step.number}</span>
              </div>
              <div class="mb-4">
                <UIComponents.gradient_icon
                  gradient_class={step.icon_gradient}
                  size="md"
                  shape="circle"
                >
                  <.icon name={step.icon} class="w-6 h-6 text-white" />
                </UIComponents.gradient_icon>
              </div>
              <h3 class="font-semibold text-lg text-hero-black mb-2">{step.title}</h3>
              <p class="text-hero-grey-700">{step.description}</p>
            </div>
          </div>
        </div>
      </div>

      <%!-- The Klass Hero Story Section --%>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24">
        <div class="text-center mb-12">
          <h2 class="font-display text-3xl md:text-4xl lg:text-5xl text-hero-black mb-4">
            {gettext("The Klass Hero Story")}
          </h2>
          <p class="text-lg text-hero-grey-700 max-w-3xl mx-auto">
            {gettext("Built by Parents and Educators for More Learning Opportunities")}
          </p>
        </div>

        <div class="max-w-3xl mx-auto space-y-6">
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "Shane spent over a decade as a coach and youth activity provider in Berlin, building Prime Youth, a community of providers, schools, and parents dedicated to giving children the best possible experiences. But one pattern kept emerging: the administrative burden of managing bookings, payments, and compliance was getting in everyone's way. Shane saw the problem from every angle. That experience became the foundation for Klass Hero."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "In 2025, Shane connected with his friend Max Pergl, a full-stack developer who shared a unique perspective. Both Shane and Max are partners of teachers who wanted to extend their expertise beyond the classroom, offering more to the community, but without the time to manage bookings, payments, and compliance on their own."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "Klass Hero was built to solve exactly that. A comprehensive operational platform that empowers educators to spend less time on paperwork and more time inspiring children."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "Konstantin Pergl, Max's brother, joined as CFO, bringing the financial rigour and strategic planning needed to navigate the German market and ensure long-term stability for every provider on the platform."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "To lead trust and quality, Laurie Camargo, a mother with over a decade of experience in child safety and quality assurance, will join to architect our Safety-First Verification engine, ensuring every Hero meets the highest standards before working with families."
            )}
          </p>
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
