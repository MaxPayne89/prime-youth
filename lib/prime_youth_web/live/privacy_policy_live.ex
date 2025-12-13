defmodule PrimeYouthWeb.PrivacyPolicyLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouthWeb.{Theme, UIComponents}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Privacy Policy")

    {:ok, socket}
  end

  defp last_updated, do: "December 12, 2025"

  defp privacy_sections do
    [
      %{
        id: "introduction",
        icon: "hero-information-circle",
        gradient: Theme.gradient(:cool),
        title: "Introduction",
        content: """
        <p class="mb-4">Welcome to Prime Youth Connect's Privacy Policy. At Prime Youth Connect, we connect families with enriching afterschool programs, camps, and educational activities. We understand that when you entrust us with your family's information, you expect us to handle it responsibly and transparently.</p>
        <p class="mb-4">This Privacy Policy explains what information we collect, how we use it, and your rights regarding your personal data. We are committed to protecting your privacy and complying with data protection laws, including GDPR.</p>
        <p class="font-semibold text-gray-900">Last Updated: #{last_updated()}</p>
        """
      },
      %{
        id: "information-collected",
        icon: "hero-document-text",
        gradient: Theme.gradient(:primary),
        title: "Information We Collect",
        content: """
        <p class="mb-4">To provide our platform services, we collect the following types of information:</p>
        <h4 class="font-semibold text-gray-900 mb-2">Account Information:</h4>
        <ul class="list-disc pl-6 mb-4 space-y-1">
          <li>Email address (for login and communication)</li>
          <li>Password (encrypted and never stored in plain text using bcrypt)</li>
          <li>Parent/guardian name</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Child Information:</h4>
        <ul class="list-disc pl-6 mb-4 space-y-1">
          <li>Child's first name (for program enrollment)</li>
          <li>Child's age or grade level (to match appropriate programs)</li>
          <li>Any special requirements or considerations provided by parents</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Booking Information:</h4>
        <ul class="list-disc pl-6 mb-4 space-y-1">
          <li>Program enrollments and preferences</li>
          <li>Schedule selections</li>
          <li>Communication history with instructors</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Payment Information:</h4>
        <ul class="list-disc pl-6 mb-4 space-y-1">
          <li>We accept credit card, direct transfer, and cash payments</li>
          <li>For credit card payments, we use third-party payment processors</li>
          <li>We do not store credit card numbers or banking details</li>
          <li>We only retain transaction records for accounting purposes</li>
        </ul>
        <h4 class="font-semibold text-gray-900 mb-2">Usage Information:</h4>
        <ul class="list-disc pl-6 space-y-1">
          <li>Pages visited on our platform</li>
          <li>Device and browser information</li>
          <li>Session data (essential for platform functionality)</li>
        </ul>
        """
      },
      %{
        id: "how-we-use",
        icon: "hero-cog-6-tooth",
        gradient: Theme.gradient(:warm_yellow),
        title: "How We Use Your Information",
        content: """
        <p class="mb-4">We use the information we collect for the following purposes:</p>
        <ul class="list-disc pl-6 space-y-2">
          <li><strong>Program Enrollment:</strong> To facilitate registration and enrollment in afterschool programs, camps, and activities</li>
          <li><strong>Communication:</strong> To send important updates about programs, bookings, and platform changes</li>
          <li><strong>Platform Improvement:</strong> To understand how our platform is used and improve functionality</li>
          <li><strong>Safety & Security:</strong> To verify instructor credentials and maintain secure facilities</li>
          <li><strong>Legal Compliance:</strong> To meet legal and regulatory requirements</li>
        </ul>
        """
      },
      %{
        id: "data-sharing",
        icon: "hero-share",
        gradient: Theme.gradient(:cool_magenta),
        title: "Data Sharing",
        content: """
        <p class="mb-4">We take your privacy seriously and limit data sharing to what's necessary:</p>
        <h4 class="font-semibold text-gray-900 mb-2">Program Instructors:</h4>
        <p class="mb-4">Instructors have access to enrolled students' names and relevant program information to provide their services effectively.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Payment Processors:</h4>
        <p class="mb-4">For credit card payments, we work with third-party payment processors who handle transaction processing securely. They only receive the information necessary to process payments.</p>
        <h4 class="font-semibold text-gray-900 mb-2">What We Don't Do:</h4>
        <ul class="list-disc pl-6 space-y-1">
          <li><strong>We never sell your personal data</strong> to third parties</li>
          <li><strong>We never share your data</strong> with advertisers or marketers</li>
          <li><strong>We never use your data</strong> for purposes other than those stated in this policy</li>
        </ul>
        """
      },
      %{
        id: "user-rights",
        icon: "hero-shield-check",
        gradient: Theme.gradient(:safety),
        title: "Your Privacy Rights",
        content: """
        <p class="mb-4">Under GDPR and other data protection laws, you have the following rights:</p>
        <h4 class="font-semibold text-gray-900 mb-2">Right to Access:</h4>
        <p class="mb-4">You can request a copy of all personal data we hold about you. Use the <strong>"Export My Data"</strong> feature in your Settings page to download your information as a JSON file.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Right to Deletion:</h4>
        <p class="mb-4">You can request deletion of your account at any time from your Settings page. When you delete your account, we immediately anonymize your email and name. Note that some information may be retained for legal or accounting purposes (such as completed booking records).</p>
        <h4 class="font-semibold text-gray-900 mb-2">Right to Correction:</h4>
        <p class="mb-4">You can update your profile information at any time through the Settings page.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Right to Data Portability:</h4>
        <p class="mb-4">Your exported data is provided in a standard JSON format that can be used with other services.</p>
        <h4 class="font-semibold text-gray-900 mb-2">Right to Object:</h4>
        <p class="mb-4">You can object to certain types of data processing. Contact us at privacy@primeyouth.com to discuss your concerns.</p>
        <p class="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <strong class="text-blue-900">To exercise any of these rights:</strong> Visit your Settings page or contact us at <a href="mailto:privacy@primeyouth.com" class="text-blue-600 hover:underline">privacy@primeyouth.com</a>
        </p>
        """
      },
      %{
        id: "data-security",
        icon: "hero-lock-closed",
        gradient: Theme.gradient(:primary),
        title: "Data Security",
        content: """
        <p class="mb-4">We take data security seriously and implement multiple layers of protection:</p>
        <ul class="list-disc pl-6 space-y-2">
          <li><strong>Encryption in Transit:</strong> All data transmitted between your device and our servers is encrypted using HTTPS</li>
          <li><strong>Password Security:</strong> Passwords are hashed using bcrypt and never stored in plain text</li>
          <li><strong>Access Controls:</strong> We limit access to personal data to authorized personnel only</li>
          <li><strong>Regular Updates:</strong> We keep our systems updated with the latest security patches</li>
          <li><strong>Monitoring:</strong> We actively monitor for security threats and suspicious activity</li>
        </ul>
        <p class="mt-4">While we implement robust security measures, no system is 100% secure. We encourage you to use strong, unique passwords and contact us immediately if you suspect unauthorized access to your account.</p>
        """
      },
      %{
        id: "children-privacy",
        icon: "hero-heart",
        gradient: Theme.gradient(:cool_magenta),
        title: "Children's Privacy",
        content: """
        <p class="mb-4">Prime Youth Connect is designed to help parents manage their children's activities. We take special care with children's information:</p>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li><strong>Parental Consent:</strong> Parents or legal guardians must create accounts and provide consent for their children's participation</li>
          <li><strong>COPPA Compliance:</strong> We comply with the Children's Online Privacy Protection Act (COPPA) for children under 13</li>
          <li><strong>Limited Collection:</strong> We only collect the minimum information necessary for program enrollment and safety</li>
          <li><strong>No Direct Marketing:</strong> We never market directly to children or collect information from them for marketing purposes</li>
        </ul>
        <p class="p-4 bg-amber-50 border border-amber-200 rounded-lg">
          <strong class="text-amber-900">Important:</strong> Children should never create accounts or provide personal information without parental permission.
        </p>
        """
      },
      %{
        id: "cookies",
        icon: "hero-computer-desktop",
        gradient: Theme.gradient(:warm_yellow),
        title: "Cookies & Tracking",
        content: """
        <p class="mb-4">Prime Youth Connect uses minimal tracking to provide essential functionality:</p>
        <h4 class="font-semibold text-gray-900 mb-2">Essential Cookies:</h4>
        <p class="mb-4">We use session cookies that are necessary for authentication and platform functionality. These cookies do not track you across other websites and are automatically deleted when you close your browser or log out.</p>
        <h4 class="font-semibold text-gray-900 mb-2">No Third-Party Tracking:</h4>
        <p class="mb-4">We do not currently use analytics, advertising, or other third-party tracking cookies. If this changes in the future, we will update this policy and request your consent before implementing such tracking.</p>
        <p class="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
          <strong class="text-green-900">Good News:</strong> Since we only use essential cookies, you don't need to worry about complex cookie consent or settings. Your privacy is protected by default.
        </p>
        """
      },
      %{
        id: "data-retention",
        icon: "hero-clock",
        gradient: Theme.gradient(:cool),
        title: "Data Retention",
        content: """
        <p class="mb-4">We retain your personal data only as long as necessary:</p>
        <ul class="list-disc pl-6 space-y-2">
          <li><strong>Active Accounts:</strong> Information is retained while your account is active and you continue using our services</li>
          <li><strong>Deleted Accounts:</strong> When you delete your account, personal identifiers (email, name) are immediately anonymized</li>
          <li><strong>Booking Records:</strong> Transaction records may be retained for legal and accounting requirements (typically 7 years)</li>
          <li><strong>Anonymized Data:</strong> Anonymized data used for statistical purposes may be retained indefinitely as it cannot be linked back to you</li>
        </ul>
        """
      },
      %{
        id: "policy-changes",
        icon: "hero-arrow-path",
        gradient: Theme.gradient(:primary),
        title: "Changes to This Policy",
        content: """
        <p class="mb-4">We may update this Privacy Policy from time to time to reflect changes in our practices or legal requirements.</p>
        <h4 class="font-semibold text-gray-900 mb-2">How We Notify You:</h4>
        <ul class="list-disc pl-6 space-y-2 mb-4">
          <li>We will update the "Last Updated" date at the top of this policy</li>
          <li>For material changes, we will send an email notification to all active users</li>
          <li>Continued use of Prime Youth Connect after changes constitute acceptance of the updated policy</li>
        </ul>
        <p>We encourage you to review this policy periodically to stay informed about how we protect your information.</p>
        """
      },
      %{
        id: "contact",
        icon: "hero-envelope",
        gradient: Theme.gradient(:cool_magenta),
        title: "Contact Us",
        content: """
        <p class="mb-4">If you have any questions about this Privacy Policy or how we handle your data, please contact us:</p>
        <div class="space-y-2">
          <p><strong>Email:</strong> <a href="mailto:privacy@primeyouth.com" class="text-blue-600 hover:underline">privacy@primeyouth.com</a></p>
          <p><strong>General Inquiries:</strong> <a href="mailto:hello@primeyouth.com" class="text-blue-600 hover:underline">hello@primeyouth.com</a></p>
        </div>
        <p class="mt-4">You can also reach us through our <a href="/contact" class="text-blue-600 hover:underline">Contact Page</a>.</p>
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
        gradient_class={Theme.gradient(:cool)}
        show_back_button
      >
        <:title>Privacy Policy</:title>
        <:subtitle>Your privacy matters to us</:subtitle>
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
              <li :for={section <- privacy_sections()}>
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

        <%!-- Privacy Policy Sections --%>
        <.card :for={section <- privacy_sections()} id={section.id}>
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
                Questions About Privacy?
              </h3>
              <p class={["text-sm mb-4", Theme.text_color(:secondary)]}>
                We're here to help with any privacy-related concerns.
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
