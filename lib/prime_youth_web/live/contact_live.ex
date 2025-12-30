defmodule PrimeYouthWeb.ContactLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Support.Application.UseCases.SubmitContactForm
  alias PrimeYouthWeb.Forms.ContactForm
  alias PrimeYouthWeb.{Theme, UIComponents}

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    changeset = ContactForm.changeset(%ContactForm{}, %{})

    socket =
      socket
      |> assign(page_title: gettext("Contact Us"))
      |> assign(current_user: nil)
      |> assign(form: to_form(changeset, as: :contact))
      |> assign(submission_status: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"contact" => contact_params}, socket) do
    changeset =
      %ContactForm{}
      |> ContactForm.changeset(contact_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :contact))}
  end

  @impl true
  def handle_event("submit", %{"contact" => contact_params}, socket) do
    case SubmitContactForm.execute(contact_params) do
      {:ok, _contact_request} ->
        {:noreply,
         socket
         |> assign(submission_status: :success)
         |> assign(form: to_form(ContactForm.changeset(%ContactForm{}, %{}), as: :contact))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :contact))}

      {:error, reason} ->
        Logger.error("Contact form submission failed: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to submit contact form. Please try again."))
         |> assign(
           form: to_form(ContactForm.changeset(%ContactForm{}, contact_params), as: :contact)
         )}
    end
  end

  defp contact_methods do
    [
      %{
        icon: "hero-envelope",
        gradient: Theme.gradient(:primary),
        title: gettext("Email"),
        value: "support@primeyouth.com",
        note: gettext("We respond within 24 hours")
      },
      %{
        icon: "hero-phone",
        gradient: Theme.gradient(:primary),
        title: gettext("Phone"),
        value: "+1 (555) 123-4567",
        note: gettext("Mon-Fri, 9am-5pm EST")
      },
      %{
        icon: "hero-map-pin",
        gradient: Theme.gradient(:primary),
        title: gettext("Address"),
        value: "123 Youth Avenue, Suite 100",
        note: "New York, NY 10001"
      }
    ]
  end

  defp office_hours do
    [
      %{days: gettext("Monday - Friday"), hours: "9:00 AM - 6:00 PM"},
      %{days: gettext("Saturday"), hours: "10:00 AM - 4:00 PM"},
      %{days: gettext("Sunday"), hours: gettext("Closed")}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pb-20 md:pb-6">
      <.hero_section
        variant="page"
        gradient_class={Theme.gradient(:primary)}
        show_back_button
      >
        <:title>{gettext("Contact Us")}</:title>
        <:subtitle>{gettext("We're here to help with any questions you may have")}</:subtitle>
      </.hero_section>

      <div class="max-w-6xl mx-auto p-6">
        <div class="grid md:grid-cols-2 gap-8">
          <div>
            <.card>
              <:header>
                <h2 class={[Theme.typography(:section_title), "text-gray-900"]}>
                  {gettext("Send us a Message")}
                </h2>
              </:header>
              <:body>
                <.form
                  for={@form}
                  id="contact-form"
                  phx-change="validate"
                  phx-submit="submit"
                  class="space-y-4"
                >
                  <.input field={@form[:name]} type="text" label={gettext("Name")} required />

                  <.input field={@form[:email]} type="email" label={gettext("Email")} required />

                  <.input
                    field={@form[:subject]}
                    type="select"
                    label={gettext("Subject")}
                    prompt={gettext("Select a topic...")}
                    options={[
                      {gettext("General Inquiry"), "general"},
                      {gettext("Program Question"), "program"},
                      {gettext("Booking Support"), "booking"},
                      {gettext("Instructor Application"), "instructor"},
                      {gettext("Technical Issue"), "technical"},
                      {gettext("Other"), "other"}
                    ]}
                    required
                  />

                  <.input
                    field={@form[:message]}
                    type="textarea"
                    label={gettext("Message")}
                    rows="5"
                    required
                  />

                  <div
                    :if={@submission_status == :success}
                    class={["p-4 bg-teal-50 border border-teal-200", Theme.rounded(:md)]}
                  >
                    <div class="flex items-center gap-2 text-teal-800">
                      <.icon name="hero-check-circle" class="w-5 h-5" />
                      <span class="font-medium">{gettext("Message sent successfully!")}</span>
                    </div>
                    <p class="text-sm text-green-700 mt-1">
                      {gettext("We'll get back to you within 24 hours.")}
                    </p>
                  </div>

                  <button
                    type="submit"
                    class={[
                      "w-full",
                      Theme.gradient(:primary),
                      "text-white py-3 px-6 font-semibold hover:shadow-lg transform hover:scale-[1.02]",
                      Theme.transition(:normal),
                      Theme.rounded(:lg)
                    ]}
                  >
                    {gettext("Send Message")}
                  </button>
                </.form>
              </:body>
            </.card>
          </div>

          <div class="space-y-6">
            <.card>
              <:header>
                <h2 class="text-xl font-bold text-gray-900">{gettext("Get in Touch")}</h2>
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

            <.card>
              <:header>
                <h2 class="text-xl font-bold text-gray-900">{gettext("Office Hours")}</h2>
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

            <.card>
              <:body>
                <div class="text-center">
                  <.icon
                    name="hero-question-mark-circle"
                    class={"w-12 h-12 mx-auto mb-3 #{Theme.text_color(:primary)}"}
                  />
                  <h3 class="font-semibold text-gray-900 mb-2">
                    {gettext("Looking for Quick Answers?")}
                  </h3>
                  <p class="text-sm text-gray-600 mb-4">
                    {gettext("Check out our FAQ section for answers to common questions.")}
                  </p>
                  <button class={[Theme.text_color(:primary), "font-medium text-sm hover:underline"]}>
                    {gettext("Visit FAQ")} →
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
end
