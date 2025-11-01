defmodule PrimeYouthWeb.ContactLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.Live.SampleFixtures, except: [contact_methods: 0, office_hours: 0]

  alias PrimeYouthWeb.UIComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Contact Us")
      |> assign(current_user: nil)
      |> assign(form: to_form(%{}, as: :contact))
      |> assign(submission_status: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if !socket.assigns.current_user, do: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
  end

  @impl true
  def handle_event("validate", %{"contact" => contact_params}, socket) do
    form = to_form(contact_params, as: :contact)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"contact" => _contact_params}, socket) do
    # TODO: Implement actual contact form submission
    # For now, just show success message

    {:noreply,
     socket
     |> assign(submission_status: :success)
     |> assign(form: to_form(%{}, as: :contact))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pb-20 md:pb-6">
      <%!-- Hero Section --%>
      <.hero_section
        variant="page"
        gradient_class="bg-gradient-to-br from-prime-cyan-400 to-prime-magenta-400"
        show_back_button
      >
        <:title>Contact Us</:title>
        <:subtitle>We're here to help with any questions you may have</:subtitle>
      </.hero_section>

      <div class="max-w-6xl mx-auto p-6">
        <div class="grid md:grid-cols-2 gap-8">
          <%!-- Contact Form --%>
          <div>
            <.card>
              <:header>
                <h2 class="text-2xl font-bold text-gray-900">Send us a Message</h2>
              </:header>
              <:body>
                <.form
                  for={@form}
                  id="contact-form"
                  phx-change="validate"
                  phx-submit="submit"
                  class="space-y-4"
                >
                  <div>
                    <label for="contact_name" class="block text-sm font-medium text-gray-700 mb-1">
                      Name
                    </label>
                    <input
                      type="text"
                      id="contact_name"
                      name="contact[name]"
                      value={@form[:name].value}
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label for="contact_email" class="block text-sm font-medium text-gray-700 mb-1">
                      Email
                    </label>
                    <input
                      type="email"
                      id="contact_email"
                      name="contact[email]"
                      value={@form[:email].value}
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label for="contact_subject" class="block text-sm font-medium text-gray-700 mb-1">
                      Subject
                    </label>
                    <select
                      id="contact_subject"
                      name="contact[subject]"
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent"
                      required
                    >
                      <option value="">Select a topic...</option>
                      <option value="general">General Inquiry</option>
                      <option value="program">Program Question</option>
                      <option value="booking">Booking Support</option>
                      <option value="instructor">Instructor Application</option>
                      <option value="technical">Technical Issue</option>
                      <option value="other">Other</option>
                    </select>
                  </div>

                  <div>
                    <label for="contact_message" class="block text-sm font-medium text-gray-700 mb-1">
                      Message
                    </label>
                    <textarea
                      id="contact_message"
                      name="contact[message]"
                      rows="5"
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent"
                      required
                    >{@form[:message].value}</textarea>
                  </div>

                  <div
                    :if={@submission_status == :success}
                    class="p-4 bg-green-50 border border-green-200 rounded-lg"
                  >
                    <div class="flex items-center gap-2 text-green-800">
                      <.icon name="hero-check-circle" class="w-5 h-5" />
                      <span class="font-medium">Message sent successfully!</span>
                    </div>
                    <p class="text-sm text-green-700 mt-1">
                      We'll get back to you within 24 hours.
                    </p>
                  </div>

                  <button
                    type="submit"
                    class="w-full bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white py-3 px-6 rounded-xl font-semibold hover:shadow-lg transform hover:scale-[1.02] transition-all"
                  >
                    Send Message
                  </button>
                </.form>
              </:body>
            </.card>
          </div>

          <%!-- Contact Information --%>
          <div class="space-y-6">
            <%!-- Contact Methods --%>
            <.card>
              <:header>
                <h2 class="text-xl font-bold text-gray-900">Get in Touch</h2>
              </:header>
              <:body>
                <div class="space-y-4">
                  <div :for={method <- contact_methods()} class="flex items-start gap-3">
                    <UIComponents.gradient_icon
                      gradient_class={method.gradient}
                      size="sm"
                      shape="circle"
                    >
                      <.icon name={method.icon} class="w-5 h-5 text-white" />
                    </UIComponents.gradient_icon>
                    <div class="flex-1">
                      <h3 class="font-semibold text-gray-900">{method.title}</h3>
                      <p class="text-sm text-gray-600">{method.value}</p>
                      <p :if={method.note} class="text-xs text-gray-500 mt-1">{method.note}</p>
                    </div>
                  </div>
                </div>
              </:body>
            </.card>

            <%!-- Office Hours --%>
            <.card>
              <:header>
                <h2 class="text-xl font-bold text-gray-900">Office Hours</h2>
              </:header>
              <:body>
                <div class="space-y-2 text-sm">
                  <div :for={hours <- office_hours()} class="flex justify-between">
                    <span class="font-medium text-gray-900">{hours.days}</span>
                    <span class="text-gray-600">{hours.hours}</span>
                  </div>
                </div>
              </:body>
            </.card>

            <%!-- FAQ Link --%>
            <.card>
              <:body>
                <div class="text-center">
                  <.icon
                    name="hero-question-mark-circle"
                    class="w-12 h-12 text-prime-cyan-400 mx-auto mb-3"
                  />
                  <h3 class="font-semibold text-gray-900 mb-2">Looking for Quick Answers?</h3>
                  <p class="text-sm text-gray-600 mb-4">
                    Check out our FAQ section for answers to common questions.
                  </p>
                  <button class="text-prime-cyan-400 font-medium text-sm hover:underline">
                    Visit FAQ →
                  </button>
                </div>
              </:body>
            </.card>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions (keeping local implementations that differ from fixtures)
  defp contact_methods do
    [
      %{
        icon: "hero-envelope",
        gradient: "bg-gradient-to-br from-prime-cyan-400 to-blue-500",
        title: "Email",
        value: "support@primeyouth.com",
        note: "We respond within 24 hours"
      },
      %{
        icon: "hero-phone",
        gradient: "bg-gradient-to-br from-prime-magenta-400 to-pink-500",
        title: "Phone",
        value: "+1 (555) 123-4567",
        note: "Mon-Fri, 9am-5pm EST"
      },
      %{
        icon: "hero-map-pin",
        gradient: "bg-gradient-to-br from-prime-yellow-400 to-orange-500",
        title: "Address",
        value: "123 Youth Avenue, Suite 100",
        note: "New York, NY 10001"
      }
    ]
  end

  defp office_hours do
    [
      %{days: "Monday - Friday", hours: "9:00 AM - 6:00 PM"},
      %{days: "Saturday", hours: "10:00 AM - 4:00 PM"},
      %{days: "Sunday", hours: "Closed"}
    ]
  end
end
