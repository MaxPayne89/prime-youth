defmodule KlassHeroWeb.TrustSafetyLive do
  use KlassHeroWeb, :live_view

  alias KlassHeroWeb.{Theme, UIComponents}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Trust & Safety"))}
  end

  defp verification_steps do
    [
      %{
        icon: "hero-identification",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Identity & Age Verification"),
        description:
          gettext(
            "All providers must be 18 years or older, ensuring legal accountability and professional responsibility."
          )
      },
      %{
        icon: "hero-academic-cap",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Experience Validation"),
        description:
          gettext(
            "Providers must demonstrate at least one year of experience working with children in their area of expertise."
          )
      },
      %{
        icon: "hero-shield-check",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Extended Background Checks"),
        description:
          gettext(
            "Each provider submits an extended police background check, confirming their eligibility to work safely with minors."
          )
      },
      %{
        icon: "hero-video-camera",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Video Screening"),
        description:
          gettext(
            "Applicants complete a video screening to assess communication skills and alignment with our values."
          )
      },
      %{
        icon: "hero-heart",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Child Safeguarding Training"),
        description:
          gettext(
            "All Heroes must hold or complete a recognized child safeguarding course, ensuring up-to-date knowledge."
          )
      },
      %{
        icon: "hero-check-circle",
        icon_gradient: "bg-hero-blue-400",
        title: gettext("Community Standards Agreement"),
        description:
          gettext(
            "Every provider agrees to follow our Community Guidelines, defining expectations around professionalism."
          )
      }
    ]
  end

  defp commitment_items do
    [
      gettext("Protect children and families"),
      gettext("Support schools and institutions with reliable providers"),
      gettext("Uphold professional and ethical teaching practices"),
      gettext("Create long-term trust across our community")
    ]
  end

  defp accountability_items do
    [
      gettext("Monitoring provider activity and feedback"),
      gettext("Enforcing platform standards and guidelines"),
      gettext("Reviewing concerns or reports promptly and seriously"),
      gettext("Taking action when standards are not met")
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen pb-20 md:pb-6", Theme.bg(:muted)]}>
      <%!-- Hero Section --%>
      <div class="bg-hero-pink-50 py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div class="flex justify-center mb-6">
            <UIComponents.gradient_icon gradient_class="bg-hero-blue-400" size="lg" shape="circle">
              <.icon name="hero-shield-check" class="w-8 h-8 text-white" />
            </UIComponents.gradient_icon>
          </div>
          <h1 class="font-display text-4xl md:text-5xl lg:text-6xl text-hero-black mb-6">
            {gettext("TRUST & SAFETY")}
          </h1>
          <p class="text-xl text-hero-grey-600 max-w-3xl mx-auto">
            {gettext(
              "At Klass Hero, trust isn't a feature — it's the foundation of everything we do. Our platform is built to connect families, schools, and organizations with qualified, vetted, and safety-verified educators and activity providers."
            )}
          </p>
        </div>
      </div>

      <%!-- Commitment to Child Safety Section --%>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24">
        <div class="grid md:grid-cols-2 gap-8 md:gap-12 items-center">
          <div class="space-y-6">
            <h2 class="font-display text-3xl md:text-4xl text-hero-black">
              {gettext("Our Commitment to Child Safety")}
            </h2>
            <p class="text-lg text-hero-grey-700 leading-relaxed">
              {gettext(
                "We believe that children thrive best in environments that are safe, respectful, and professionally led. That's why Klass Hero applies a multi-layered safety and verification framework before any provider can offer sessions on our platform."
              )}
            </p>
            <div class="grid grid-cols-1 gap-4">
              <div
                :for={item <- commitment_items()}
                class="flex items-center gap-3 bg-white p-4 rounded-xl border-2 border-hero-yellow-400"
              >
                <.icon name="hero-check-circle" class="w-5 h-5 text-hero-blue-600 flex-shrink-0" />
                <span class="font-bold text-hero-black">{item}</span>
              </div>
            </div>
          </div>
          <div class="bg-hero-blue-600 rounded-2xl p-8 text-white relative overflow-hidden">
            <h3 class="text-2xl font-display text-white mb-4">
              {gettext("Vetted with Care")}
            </h3>
            <p class="text-white/90 mb-6 text-lg">
              {gettext(
                "From academic tutoring to sports, arts, and enrichment programs, every provider on Klass Hero is carefully reviewed to ensure they meet our high standards for child safety, professionalism, and educational quality."
              )}
            </p>
            <div class="h-1 w-20 bg-hero-yellow-400 mb-6"></div>
            <.icon
              name="hero-shield-check"
              class="w-24 h-24 text-white/20 absolute bottom-0 right-0 -mb-6 -mr-6"
            />
          </div>
        </div>
      </div>

      <%!-- 6-Step Verification Process --%>
      <div class="bg-hero-pink-50 py-12 md:py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class="font-display text-3xl md:text-4xl lg:text-5xl text-hero-black mb-4">
              {gettext("How We Verify Providers")}
            </h2>
            <p class="text-lg text-hero-grey-700 max-w-3xl mx-auto">
              {gettext(
                "Every educator and enrichment professional on Klass Hero completes a 6-step verification process before being approved."
              )}
            </p>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8">
            <div :for={step <- verification_steps()} class="bg-white rounded-xl p-6 text-center">
              <div class="mb-4 flex justify-center">
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

      <%!-- Ongoing Quality & Accountability --%>
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24">
        <div class="bg-gray-900 rounded-2xl p-8 md:p-10 text-white">
          <h2 class="text-3xl font-display mb-8 text-hero-yellow-400">
            {gettext("Ongoing Quality & Accountability")}
          </h2>
          <p class="text-gray-300 mb-8 text-lg">
            {gettext(
              "Trust doesn't stop at onboarding. Klass Hero continuously works to maintain a safe and high-quality ecosystem by:"
            )}
          </p>
          <ul class="space-y-4 mb-10">
            <li
              :for={{item, index} <- Enum.with_index(accountability_items(), 1)}
              class="flex items-start gap-3"
            >
              <div class="w-6 h-6 rounded-full bg-hero-yellow-400 flex-shrink-0 flex items-center justify-center text-hero-black font-bold text-xs mt-1">
                {index}
              </div>
              <span class="text-lg">{item}</span>
            </li>
          </ul>
          <p class="text-gray-400 italic border-l-4 border-hero-yellow-400 pl-4">
            {gettext(
              "Providers who fail to uphold our expectations may be suspended or removed from the platform."
            )}
          </p>
        </div>
      </div>

      <%!-- CTA Section --%>
      <div class="bg-hero-pink-50 py-16 text-center">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 class="font-display text-3xl md:text-4xl text-hero-black mb-4">
            {gettext("Have Questions?")}
          </h2>
          <p class="text-lg text-hero-grey-700 mb-8">
            {gettext(
              "If you'd like to learn more about our Trust & Safety standards or provider verification process, we're happy to help."
            )}
          </p>
          <.link
            navigate={~p"/contact"}
            class="inline-block bg-hero-blue-600 hover:bg-hero-blue-700 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-all duration-200 transform hover:scale-105"
          >
            {gettext("Contact Us")}
          </.link>
          <div class="mt-12">
            <div class="h-px w-32 bg-hero-grey-300 mx-auto mb-8"></div>
            <p class="text-2xl font-display text-hero-black tracking-widest">
              {gettext("Trust is earned. Safety is non-negotiable.")}
            </p>
            <p class="text-xl text-hero-blue-600 font-bold mt-2">
              {gettext("And at Klass Hero, both come standard.")}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
