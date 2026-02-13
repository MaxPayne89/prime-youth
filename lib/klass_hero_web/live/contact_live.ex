defmodule KlassHeroWeb.ContactLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Support.Application.UseCases.SubmitContactForm
  alias KlassHero.Support.Domain.Models.ContactForm
  alias KlassHeroWeb.{Theme, UIComponents}

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
        type: :email,
        icon: "hero-envelope",
        title: gettext("Email"),
        value: "support@primeyouth.com",
        note: gettext("We respond within 24 hours")
      },
      %{
        type: :phone,
        icon: "hero-phone",
        title: gettext("Phone"),
        value: "+1 (555) 123-4567",
        note: gettext("Mon-Fri, 9am-5pm EST")
      },
      %{
        type: :address,
        icon: "hero-map-pin",
        title: gettext("Address"),
        value: "123 Youth Avenue, Suite 100",
        note: "New York, NY 10001"
      }
    ]
  end

  @contact_colors %{
    email: %{border: "rgb(102 204 255)", gradient: "bg-hero-blue-400"},
    phone: %{border: "rgb(34 197 94)", gradient: "bg-green-500"},
    address: %{border: "rgb(255 255 54)", gradient: "bg-hero-yellow-500"}
  }

  defp contact_color(type, key), do: @contact_colors[type][key]

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
    <div class="min-h-screen pb-20 md:pb-6">
      <%!-- Dark Hero Section --%>
      <div class="bg-hero-black py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 class="font-display text-4xl md:text-5xl lg:text-6xl text-white mb-6">
            {gettext("Contact Us")}
          </h1>
          <p class="text-xl text-white/80 max-w-3xl mx-auto">
            {gettext("We're here to help with any questions you may have")}
          </p>
        </div>
      </div>

      <%!-- Main Content - White Background --%>
      <div class="bg-white py-12 md:py-16 lg:py-24">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid md:grid-cols-2 gap-8">
            <div>
              <.card>
                <:header>
                  <h2 class={[Theme.typography(:section_title), "text-hero-black"]}>
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
                      class={["p-4 bg-hero-blue-50 border border-hero-blue-200", Theme.rounded(:md)]}
                    >
                      <div class="flex items-center gap-2 text-hero-blue-800">
                        <.icon name="hero-check-circle" class="w-5 h-5" />
                        <span class="font-medium">{gettext("Message sent successfully!")}</span>
                      </div>
                      <p class="text-sm text-green-700 mt-1">
                        {gettext("We'll get back to you within 24 hours.")}
                      </p>
                    </div>

                    <button
                      type="submit"
                      class="w-full bg-hero-blue-500 hover:bg-hero-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-all duration-200 transform hover:scale-105"
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
                  <h2 class="text-xl font-bold text-hero-black">{gettext("Get in Touch")}</h2>
                </:header>
                <:body>
                  <div class="space-y-4">
                    <div
                      :for={method <- contact_methods()}
                      class="border-2 rounded-lg p-6 bg-white flex items-start gap-4"
                      style={"border-color: #{contact_color(method.type, :border)}"}
                    >
                      <div class="flex-shrink-0">
                        <UIComponents.gradient_icon
                          gradient_class={contact_color(method.type, :gradient)}
                          size="md"
                          shape="circle"
                        >
                          <.icon name={method.icon} class="w-6 h-6 text-white" />
                        </UIComponents.gradient_icon>
                      </div>
                      <div class="flex-1">
                        <h3 class="font-semibold text-hero-black">{method.title}</h3>
                        <p class="text-sm text-hero-grey-600">{method.value}</p>
                        <p :if={method.note} class="text-xs text-hero-grey-500 mt-1">{method.note}</p>
                      </div>
                    </div>
                  </div>
                </:body>
              </.card>

              <.card>
                <:header>
                  <h2 class="text-xl font-bold text-hero-black">{gettext("Office Hours")}</h2>
                </:header>
                <:body>
                  <div class="space-y-2 text-sm">
                    <div :for={hours <- office_hours()} class="flex justify-between">
                      <span class="font-medium text-hero-black">{hours.days}</span>
                      <span class="text-hero-grey-600">{hours.hours}</span>
                    </div>
                  </div>
                </:body>
              </.card>

              <.card>
                <:body>
                  <div class="text-center">
                    <UIComponents.gradient_icon
                      gradient_class="bg-hero-blue-500"
                      size="lg"
                      shape="circle"
                      class="mx-auto mb-4"
                    >
                      <.icon name="hero-question-mark-circle" class="w-8 h-8 text-white" />
                    </UIComponents.gradient_icon>
                    <h3 class="font-semibold text-hero-black mb-2">
                      {gettext("Looking for Quick Answers?")}
                    </h3>
                    <p class="text-sm text-hero-grey-600 mb-4">
                      {gettext("Check out our FAQ section for answers to common questions.")}
                    </p>
                    <button class="text-hero-blue-500 font-medium text-sm hover:underline">
                      {gettext("Visit FAQ")} →
                    </button>
                  </div>
                </:body>
              </.card>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
