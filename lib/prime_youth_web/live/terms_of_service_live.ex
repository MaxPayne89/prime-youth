defmodule PrimeYouthWeb.TermsOfServiceLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouthWeb.{Theme, UIComponents}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Terms of Service")

    {:ok, socket}
  end

  defp last_updated, do: "December 12, 2025"

  defp terms_sections do
    [
      %{
        id: "agreement",
        icon: "hero-document-check",
        gradient: Theme.gradient(:primary),
        title: "Agreement to Terms",
        content: """
        <p class="mb-4">By accessing and using Prime Youth ("the Platform"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our services.</p>
        <p class="mb-4">These terms constitute a legally binding agreement between you and Prime Youth. Please read them carefully.</p>
        <p class="font-semibold text-gray-900">Last Updated: #{last_updated()}</p>
        """
      },
      %{
        id: "user-accounts",
        icon: "hero-user-circle",
        gradient: Theme.gradient(:cool),
        title: "User Accounts & Registration",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Account Creation:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>You must be at least 18 years old to create an account</li>
          <li>Parents or legal guardians must create accounts for their children</li>
          <li>You must provide accurate and complete information during registration</li>
          <li>You are responsible for maintaining the confidentiality of your account credentials</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Account Responsibilities:</h4>
        <ul class="list-disc pl-6 space-y-2">
          <li>You are responsible for all activities that occur under your account</li>
          <li>Notify us immediately if you suspect unauthorized access to your account</li>
          <li>Do not share your account credentials with others</li>
          <li>Keep your contact information up to date</li>
        </ul>
        """
      },
      %{
        id: "program-enrollment",
        icon: "hero-academic-cap",
        gradient: Theme.gradient(:warm_yellow),
        title: "Program Enrollment & Bookings",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Enrollment Process:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>Program availability is subject to capacity and scheduling</li>
          <li>Enrollment is not confirmed until you receive a confirmation email</li>
          <li>Program details (schedule, location, instructor) are subject to change with notice</li>
          <li>You must provide accurate information about your child for safety purposes</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Attendance:</h4>
        <ul class="list-disc pl-6 space-y-2">
          <li>Parents are responsible for ensuring timely drop-off and pick-up</li>
          <li>Notify instructors in advance if your child cannot attend a session</li>
          <li>Repeated absences without notice may result in enrollment termination</li>
        </ul>
        """
      },
      %{
        id: "payment-terms",
        icon: "hero-credit-card",
        gradient: Theme.gradient(:cool_magenta),
        title: "Payment Terms",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Accepted Payment Methods:</h4>
        <p class="mb-4">We accept the following payment methods:</p>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li><strong>Credit Card:</strong> Processed securely through our payment processor</li>
          <li><strong>Direct Bank Transfer:</strong> Details provided upon enrollment confirmation</li>
          <li><strong>Cash:</strong> Accepted at select locations (subject to program availability)</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Payment Schedule:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>Payment is due at the time of enrollment unless otherwise specified</li>
          <li>Some programs may offer installment plans or payment schedules</li>
          <li>Late payments may result in enrollment suspension</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Pricing:</h4>
        <ul class="list-disc pl-6 space-y-2">
          <li>All prices are displayed clearly before enrollment</li>
          <li>Prices are subject to change but will not affect existing enrollments</li>
          <li>Additional fees (materials, field trips) will be communicated in advance</li>
        </ul>
        """
      },
      %{
        id: "cancellation-refund",
        icon: "hero-arrow-uturn-left",
        gradient: Theme.gradient(:safety),
        title: "Cancellation & Refund Policy",
        content: """
        <p class="mb-4"><em class="text-amber-600">Note: This is a basic policy template. Specific terms may vary by program and will be provided during enrollment.</em></p>
        <h4 class="font-semibold text-gray-900 mb-2">User Cancellations:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li><strong>Early Cancellation:</strong> Full refund if canceled 7+ days before program start</li>
          <li><strong>Late Cancellation:</strong> 50% refund if canceled 3-6 days before program start</li>
          <li><strong>Last Minute:</strong> No refund if canceled less than 3 days before start</li>
          <li>Refunds are processed within 10 business days</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Program Cancellations:</h4>
        <ul class="list-disc pl-6 space-y-2">
          <li>If Prime Youth or an instructor cancels a program, you will receive a full refund</li>
          <li>Weather-related cancellations will be rescheduled when possible</li>
          <li>We will notify you as soon as possible of any cancellations</li>
        </ul>
        """
      },
      %{
        id: "user-conduct",
        icon: "hero-shield-check",
        gradient: Theme.gradient(:primary),
        title: "User Conduct & Responsibilities",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Expected Behavior:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>Treat instructors, staff, and other families with respect</li>
          <li>Follow program rules and safety guidelines</li>
          <li>Do not disrupt programs or activities</li>
          <li>Report any safety concerns immediately</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Prohibited Activities:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>Harassment, discrimination, or abusive behavior</li>
          <li>Providing false information during registration</li>
          <li>Unauthorized recording or photography of other children</li>
          <li>Use of the Platform for any illegal purposes</li>
        </ul>
        <p class="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <strong class="text-red-900">Important:</strong> Violation of these terms may result in immediate termination of your account and enrollment without refund.
        </p>
        """
      },
      %{
        id: "liability",
        icon: "hero-exclamation-triangle",
        gradient: Theme.gradient(:warm_yellow),
        title: "Limitation of Liability",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Platform Use:</h4>
        <p class="mb-4">Prime Youth provides a platform to connect families with program instructors. While we verify instructor credentials and monitor program quality, the actual programs are provided by independent instructors.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Liability Limits:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>We are not liable for injuries or accidents that occur during programs</li>
          <li>Parents are responsible for ensuring their child's suitability for chosen activities</li>
          <li>We recommend appropriate insurance coverage for participating children</li>
          <li>Emergency contact information must be kept current</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Service Availability:</h4>
        <p class="mb-4">We strive to keep the Platform available, but we cannot guarantee uninterrupted access. We are not liable for service interruptions or technical issues.</p>
        <p class="mt-4 text-sm italic text-gray-600">
          To the extent permitted by law, Prime Youth's total liability shall not exceed the amount you paid for services in the 12 months preceding any claim.
        </p>
        """
      },
      %{
        id: "intellectual-property",
        icon: "hero-sparkles",
        gradient: Theme.gradient(:cool),
        title: "Intellectual Property",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Platform Content:</h4>
        <p class="mb-4">All content on Prime Youth, including text, graphics, logos, and software, is owned by Prime Youth or licensed to us and protected by copyright and trademark laws.</p>
        <h4 class="font-semibold text-gray-900 mb-2">User Content:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>You retain ownership of any content you submit (reviews, photos with permission)</li>
          <li>By submitting content, you grant us a license to use it for Platform operations</li>
          <li>Do not submit content that infringes on others' intellectual property rights</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Restrictions:</h4>
        <ul class="list-disc pl-6 space-y-2">
          <li>Do not copy, modify, or distribute Platform content without permission</li>
          <li>Do not use automated tools to access or scrape the Platform</li>
          <li>Do not reverse engineer or attempt to extract source code</li>
        </ul>
        """
      },
      %{
        id: "changes-to-terms",
        icon: "hero-arrow-path",
        gradient: Theme.gradient(:cool_magenta),
        title: "Changes to Terms",
        content: """
        <p class="mb-4">We may update these Terms of Service from time to time to reflect changes in our practices, legal requirements, or service offerings.</p>
        <h4 class="font-semibold text-gray-900 mb-2">How We Notify You:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>We will update the "Last Updated" date at the top of these terms</li>
          <li>For material changes, we will send an email notification to all active users</li>
          <li>Continued use of Prime Youth after changes constitute acceptance of the updated terms</li>
          <li>If you disagree with changes, you may terminate your account</li>
        </ul>
        <p>We encourage you to review these terms periodically to stay informed.</p>
        """
      },
      %{
        id: "termination",
        icon: "hero-x-circle",
        gradient: Theme.gradient(:primary),
        title: "Account Termination",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Your Right to Terminate:</h4>
        <p class="mb-4">You may delete your account at any time through your Settings page. Upon deletion, your personal information will be anonymized as described in our Privacy Policy.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Our Right to Terminate:</h4>
        <p class="mb-4">We reserve the right to suspend or terminate accounts that violate these terms, engage in fraudulent activity, or pose a safety risk. We will provide notice when possible, but may terminate immediately for serious violations.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Effect of Termination:</h4>
        <ul class="list-disc pl-6 space-y-2">
          <li>Active enrollments will be handled on a case-by-case basis</li>
          <li>You will lose access to Platform features and history</li>
          <li>Provisions regarding liability, intellectual property, and dispute resolution survive termination</li>
        </ul>
        """
      },
      %{
        id: "dispute-resolution",
        icon: "hero-scale",
        gradient: Theme.gradient(:safety),
        title: "Dispute Resolution",
        content: """
        <h4 class="font-semibold text-gray-900 mb-2">Contact Us First:</h4>
        <p class="mb-4">If you have a dispute or concern, please contact us first at hello@primeyouth.com. We are committed to resolving issues amicably and will work with you in good faith.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Informal Resolution:</h4>
        <p class="mb-4">Most concerns can be resolved through direct communication. We will respond to disputes within 5 business days and work toward a fair resolution.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Governing Law:</h4>
        <p class="mb-4">These Terms of Service are governed by and construed in accordance with the laws of your jurisdiction, without regard to conflict of law principles.</p>
        <p class="mt-4 text-sm italic text-gray-600">
          If informal resolution is unsuccessful, any disputes will be resolved through binding arbitration in accordance with applicable arbitration rules.
        </p>
        """
      },
      %{
        id: "contact",
        icon: "hero-envelope",
        gradient: Theme.gradient(:warm_yellow),
        title: "Contact Information",
        content: """
        <p class="mb-4">If you have questions about these Terms of Service, please contact us:</p>
        <div class="space-y-2">
          <p><strong>Email:</strong> <a href="mailto:hello@primeyouth.com" class="text-blue-600 hover:underline">hello@primeyouth.com</a></p>
          <p><strong>Privacy Questions:</strong> <a href="mailto:privacy@primeyouth.com" class="text-blue-600 hover:underline">privacy@primeyouth.com</a></p>
        </div>
        <p class="mt-4">You can also reach us through our <a href="/contact" class="text-blue-600 hover:underline">Contact Page</a>.</p>
        <p class="mt-6 p-4 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-700">
          By using Prime Youth, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and our Privacy Policy.
        </p>
        """
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen pb-20 md:pb-6", Theme.bg(:muted)]}>
      <%!-- Hero Section --%>
      <.hero_section
        variant="page"
        gradient_class={Theme.gradient(:primary)}
        show_back_button
      >
        <:title>Terms of Service</:title>
        <:subtitle>Understanding our agreement with you</:subtitle>
      </.hero_section>

      <div class="max-w-4xl mx-auto p-6 space-y-6">
        <%!-- Last Updated Banner --%>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p class="text-sm text-blue-800">
            <span class="font-semibold">Last Updated:</span> {last_updated()}
          </p>
        </div>

        <%!-- Table of Contents Card --%>
        <.card>
          <:header>
            <h2 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
              Table of Contents
            </h2>
          </:header>
          <:body>
            <ul class="space-y-2">
              <li :for={section <- terms_sections()}>
                <a
                  href={"##{section.id}"}
                  class="text-blue-600 hover:underline flex items-center gap-2"
                >
                  <.icon name={section.icon} class="w-4 h-4" />
                  {section.title}
                </a>
              </li>
            </ul>
          </:body>
        </.card>

        <%!-- Terms of Service Sections --%>
        <.card :for={section <- terms_sections()} id={section.id}>
          <:header>
            <div class="flex items-center gap-3">
              <UIComponents.gradient_icon
                gradient_class={section.gradient}
                size="sm"
                shape="circle"
              >
                <.icon name={section.icon} class="w-5 h-5 text-white" />
              </UIComponents.gradient_icon>
              <h2 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
                {section.title}
              </h2>
            </div>
          </:header>
          <:body>
            <div class={["prose prose-sm max-w-none", Theme.text_color(:secondary)]}>
              {raw(section.content)}
            </div>
          </:body>
        </.card>

        <%!-- Contact CTA Section --%>
        <.card padding="p-8">
          <:body>
            <div class="text-center">
              <h3 class={["font-semibold mb-2", Theme.text_color(:heading)]}>
                Questions About These Terms?
              </h3>
              <p class={["text-sm mb-4", Theme.text_color(:secondary)]}>
                We're here to clarify any questions you may have.
              </p>
              <.link
                navigate={~p"/contact"}
                class={[
                  "inline-block",
                  Theme.gradient(:primary),
                  "text-white px-6 py-2 text-sm font-semibold hover:shadow-lg transform hover:scale-[1.02]",
                  Theme.transition(:normal),
                  Theme.rounded(:lg)
                ]}
              >
                Contact Us
              </.link>
            </div>
          </:body>
        </.card>
      </div>
    </div>
    """
  end
end
