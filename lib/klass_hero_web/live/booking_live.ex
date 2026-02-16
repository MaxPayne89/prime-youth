defmodule KlassHeroWeb.BookingLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.BookingComponents
  import KlassHeroWeb.Helpers.FamilyHelpers

  alias KlassHero.Enrollment
  alias KlassHero.ProgramCatalog
  alias KlassHeroWeb.Presenters.ChildPresenter
  alias KlassHeroWeb.Theme

  @default_weekly_fee 45.00
  @default_weeks_count 8
  @default_registration_fee 25.00
  @default_vat_rate 0.19
  @default_card_processing_fee 2.50

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    current_user = socket.assigns.current_scope.user

    with {:ok, program} <- fetch_program(program_id),
         :ok <- validate_registration_open(program) do
      children = get_children_for_current_user(socket)
      children_for_view = Enum.map(children, &ChildPresenter.to_simple_view/1)
      children_by_id = Map.new(children, &{&1.id, &1})

      socket =
        socket
        |> assign(
          page_title: gettext("Enrollment - %{title}", title: program.title),
          current_user: current_user,
          program: program,
          children: children_for_view,
          children_by_id: children_by_id,
          selected_child_id: nil,
          special_requirements: "",
          payment_method: "card",
          weekly_fee: @default_weekly_fee,
          weeks_count: @default_weeks_count,
          registration_fee: @default_registration_fee,
          vat_rate: @default_vat_rate,
          card_fee: @default_card_processing_fee
        )
        |> apply_fee_calculation()
        |> assign_booking_limit_info()

      {:ok, socket}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Program not found"))
         |> redirect(to: ~p"/programs")}

      {:error, :no_spots} ->
        program_for_redirect = fetch_program_unsafe(program_id)

        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("Sorry, this program is currently full. Check back later for availability.")
         )
         |> redirect(to: ~p"/programs/#{program_for_redirect.id}")}

      {:error, :registration_not_open} ->
        program_for_redirect = fetch_program_unsafe(program_id)

        {:ok,
         socket
         |> put_flash(:error, gettext("Registration is not currently open for this program."))
         |> redirect(to: ~p"/programs/#{program_for_redirect.id}")}

      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Unable to load program. Please try again later."))
         |> redirect(to: ~p"/programs")}
    end
  end

  @impl true
  def handle_event("back_to_program", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs/#{socket.assigns.program.id}")}
  end

  @impl true
  def handle_event("select_payment_method", %{"method" => method}, socket) do
    socket =
      socket
      |> assign(payment_method: method)
      |> apply_fee_calculation()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_child", %{"child_id" => child_id}, socket) do
    # Trigger: parent picks a child from the dropdown
    # Why: pre-fill special requirements from stored medical/support data
    # Outcome: textarea shows child's known needs, parent can edit before submitting
    child = Map.get(socket.assigns.children_by_id, child_id)

    special_requirements = build_special_requirements(child)

    {:noreply,
     assign(socket, selected_child_id: child_id, special_requirements: special_requirements)}
  end

  @impl true
  def handle_event("complete_enrollment", params, socket) do
    with :ok <- validate_enrollment_data(socket, params),
         :ok <- validate_payment_method(socket),
         :ok <- validate_registration_open(socket.assigns.program),
         {:ok, _enrollment} <- create_enrollment(socket, params) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext("Enrollment successful! You'll receive a confirmation email shortly.")
       )
       |> push_navigate(to: ~p"/dashboard")}
    else
      {:error, :no_spots} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Sorry, this program is now full. Please choose another program.")
         )
         |> push_navigate(to: ~p"/programs")}

      {:error, :registration_not_open} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Registration has closed for this program."))
         |> push_navigate(to: ~p"/programs/#{socket.assigns.program.id}")}

      {:error, :invalid_payment} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Payment information is invalid. Please check your details.")
         )}

      {:error, :child_not_selected} ->
        {:noreply, put_flash(socket, :error, gettext("Please select a child for enrollment."))}

      {:error, :booking_limit_exceeded} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext(
             "You've reached your monthly booking limit. Upgrade to Active tier for unlimited bookings."
           )
         )}

      {:error, :no_parent_profile} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Please complete your profile before making a booking."))
         |> push_navigate(to: ~p"/settings")}

      {:error, :processing_failed} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Enrollment failed. Please try again or contact support.")
         )}
    end
  end

  defp fetch_program(id) do
    ProgramCatalog.get_program_by_id(id)
  end

  defp fetch_program_unsafe(program_id) do
    case ProgramCatalog.get_program_by_id(program_id) do
      {:ok, program} -> program
      {:error, _} -> %{id: program_id}
    end
  end

  defp apply_fee_calculation(socket) do
    {:ok, fees} =
      Enrollment.calculate_fees(%{
        weekly_fee: socket.assigns.weekly_fee,
        registration_fee: socket.assigns.registration_fee,
        vat_rate: socket.assigns.vat_rate,
        card_fee: socket.assigns.card_fee,
        payment_method: socket.assigns.payment_method
      })

    assign(socket,
      subtotal: fees.subtotal,
      vat_amount: fees.vat_amount,
      card_fee_amount: fees.card_fee_amount,
      total: fees.total
    )
  end

  defp validate_registration_open(program) do
    # Trigger: program has a registration_period field
    # Why: prevent bookings outside the configured registration window
    # Outcome: blocks mount and enrollment if registration is closed
    if ProgramCatalog.registration_open?(program) do
      :ok
    else
      {:error, :registration_not_open}
    end
  end

  defp validate_enrollment_data(_socket, %{"child_id" => child_id})
       when is_binary(child_id) and byte_size(child_id) > 0, do: :ok

  defp validate_enrollment_data(_socket, _params), do: {:error, :child_not_selected}

  defp validate_payment_method(socket) do
    case socket.assigns.payment_method do
      method when method in ["card", "transfer"] -> :ok
      _ -> {:error, :invalid_payment}
    end
  end

  defp create_enrollment(socket, params) do
    identity_id = socket.assigns.current_scope.user.id

    enrollment_params = %{
      identity_id: identity_id,
      program_id: socket.assigns.program.id,
      child_id: params["child_id"],
      payment_method: socket.assigns.payment_method,
      subtotal: socket.assigns.subtotal,
      vat_amount: socket.assigns.vat_amount,
      card_fee_amount: socket.assigns.card_fee_amount,
      total_amount: socket.assigns.total,
      special_requirements: params["special_requirements"]
    }

    Enrollment.create_enrollment(enrollment_params)
  end

  defp assign_booking_limit_info(socket) do
    identity_id = socket.assigns.current_scope.user.id

    case Enrollment.get_booking_usage_info(identity_id) do
      {:ok, info} ->
        assign(socket,
          booking_tier: info.tier,
          booking_cap: info.cap,
          bookings_used: info.used,
          bookings_remaining: info.remaining
        )

      {:error, :no_parent_profile} ->
        assign(socket,
          booking_tier: nil,
          booking_cap: nil,
          bookings_used: 0,
          bookings_remaining: :unlimited
        )
    end
  end

  defp build_special_requirements(nil), do: ""

  defp build_special_requirements(child) do
    [child.allergies, child.support_needs]
    |> Enum.reject(&(is_nil(&1) or String.trim(&1) == ""))
    |> Enum.join("\n")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.gradient(:hero)]}>
      <div class="max-w-4xl mx-auto px-4 py-6">
        <.page_header
          variant={:gradient}
          show_back_button
          phx-click="back_to_program"
          class="!p-0 !bg-transparent !shadow-none mb-6"
        >
          <:title>
            <h1 class={[Theme.typography(:page_title), "text-white"]}>{gettext("Enrollment")}</h1>
          </:title>
        </.page_header>

        <div class="mb-6">
          <h3 class="text-white font-semibold mb-3">{gettext("Activity Summary")}</h3>
          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <div class="flex gap-4 mb-4">
              <div class={[
                "w-16 h-16 flex items-center justify-center text-3xl",
                Theme.rounded(:lg),
                Theme.gradient(:hero)
              ]}>
                🎨
              </div>
              <div>
                <h4 class={[Theme.typography(:card_title), "mb-1", Theme.text_color(:heading)]}>
                  {@program.title}
                </h4>
                <p class={["text-sm", Theme.text_color(:secondary)]}>
                  {gettext("Wednesdays 4-6 PM")}
                </p>
              </div>
            </div>
            <div class={["border-t pt-4", Theme.border_color(:medium)]}>
              <div class="flex justify-between items-center mb-2">
                <span class={["font-semibold", Theme.text_color(:body)]}>
                  {gettext("Total Price:")}
                </span>
                <span class={[Theme.typography(:section_title), Theme.text_color(:primary)]}>
                  €{:erlang.float_to_binary(@total, decimals: 2)}
                </span>
              </div>
              <div class="flex justify-between text-sm">
                <span class={Theme.text_color(:secondary)}>{gettext("Duration:")}</span>
                <span class={Theme.text_color(:secondary)}>{gettext("Jan 15 - Mar 15, 2024")}</span>
              </div>
            </div>
          </div>
          <div class="mt-2">
            <a href="#" class="text-xs text-white/80 hover:text-white underline">
              {gettext("Add another program")}
            </a>
          </div>
        </div>

        <.info_box
          :if={@bookings_remaining != :unlimited}
          variant={:info}
          icon="📊"
          title={gettext("Your Booking Plan")}
          class="mb-6"
        >
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm">
                {gettext("You have %{remaining} of %{total} bookings remaining this month.",
                  remaining: @bookings_remaining,
                  total: @booking_cap
                )}
              </p>
              <p class="text-xs text-hero-blue-600 mt-1">
                <span class="capitalize">{@booking_tier}</span> {gettext("tier")}
              </p>
            </div>
            <.link
              navigate={~p"/settings"}
              class="text-sm text-hero-blue-600 hover:text-hero-blue-800 underline"
            >
              {gettext("Upgrade")}
            </.link>
          </div>
        </.info_box>

        <form phx-submit="complete_enrollment" class="space-y-6">
          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <label class={["block text-sm font-semibold mb-3", Theme.text_color(:body)]}>
              {gettext("Select Child")}
            </label>
            <select
              name="child_id"
              phx-change="select_child"
              class={[
                "w-full px-4 py-3 border border-hero-grey-300 focus:ring-2 focus:ring-hero-blue-500 focus:border-transparent",
                Theme.rounded(:lg)
              ]}
            >
              <option value="">{gettext("Select a child")}</option>
              <option
                :for={child <- @children}
                value={child.id}
                selected={child.id == @selected_child_id}
              >
                {gettext("%{name} (Age %{age})", name: child.name, age: child.age)}
              </option>
            </select>
            <div class="mt-2">
              <a
                href="#"
                class={[
                  "text-xs underline",
                  Theme.text_color(:muted),
                  "hover:#{Theme.text_color(:body)}"
                ]}
              >
                {gettext("Add another child")}
              </a>
            </div>
          </div>

          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <label
              for="special-requirements"
              class={["block text-sm font-semibold mb-3", Theme.text_color(:body)]}
            >
              {gettext("Special Requirements")}
            </label>
            <textarea
              id="special-requirements"
              name="special_requirements"
              rows="3"
              maxlength="500"
              placeholder={gettext("Any allergies, medical conditions, or special instructions...")}
              class={[
                "w-full px-4 py-3 border border-hero-grey-300 focus:ring-2 focus:ring-hero-blue-500 focus:border-transparent resize-none",
                Theme.rounded(:lg)
              ]}
            >{@special_requirements}</textarea>
            <div class="flex justify-between mt-2">
              <p class={["text-xs", Theme.text_color(:muted)]}>
                {gettext(
                  "Optional: Include any important information we should know about your child."
                )}
              </p>
              <p class={["text-xs", Theme.text_color(:muted)]}>0/500</p>
            </div>
          </div>

          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <fieldset>
              <legend class={["block text-sm font-semibold mb-3", Theme.text_color(:body)]}>
                {gettext("Payment Method")}
              </legend>
              <div class="space-y-3">
                <.payment_option
                  value="card"
                  title={gettext("Credit Card")}
                  description={gettext("Pay securely with Visa, Mastercard, or other cards")}
                  selected={@payment_method == "card"}
                  phx-click="select_payment_method"
                  phx-value-method="card"
                />

                <.payment_option
                  value="transfer"
                  title={gettext("Cash / Bank Transfer")}
                  description={gettext("Avoid card fees - pay cash or direct transfer")}
                  selected={@payment_method == "transfer"}
                  phx-click="select_payment_method"
                  phx-value-method="transfer"
                />
              </div>
            </fieldset>
          </div>

          <.booking_summary title={gettext("Payment Summary")}>
            <:line_item
              label={gettext("Weekly fee (%{count} weeks):", count: @weeks_count)}
              value={"€#{:erlang.float_to_binary(@weekly_fee, decimals: 2)}"}
            />
            <:line_item
              label={gettext("Registration fee:")}
              value={"€#{:erlang.float_to_binary(@registration_fee, decimals: 2)}"}
            />
            <:subtotal
              label={gettext("Subtotal:")}
              value={"€#{:erlang.float_to_binary(@subtotal, decimals: 2)}"}
            />
            <:line_item
              label={gettext("VAT (19%):")}
              value={"€#{:erlang.float_to_binary(@vat_amount, decimals: 2)}"}
              after_subtotal={true}
            />
            <:line_item
              :if={@payment_method == "card"}
              label={gettext("Credit card fee:")}
              value={"€#{:erlang.float_to_binary(@card_fee_amount, decimals: 2)}"}
              after_subtotal={true}
            />
            <:total
              label={gettext("Total due today:")}
              value={"€#{:erlang.float_to_binary(@total, decimals: 2)}"}
            />
          </.booking_summary>

          <.info_box
            :if={@payment_method == "transfer"}
            variant={:info}
            title={gettext("Bank Transfer Details")}
          >
            <p class="mb-4">
              {gettext("Please transfer")}
              <strong>€{:erlang.float_to_binary(@total, decimals: 2)}</strong>
              {gettext("(no card fees) to the following account:")}
            </p>
            <div class="space-y-2 font-mono text-sm">
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>{gettext("Account Name:")}</span>
                <span class="font-semibold">Klass Hero</span>
              </div>
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>{gettext("IBAN:")}</span>
                <span class="font-semibold">IE64 BOFI 9000 1234 5678 90</span>
              </div>
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>{gettext("BIC:")}</span>
                <span class="font-semibold">BOFIIE2D</span>
              </div>
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>{gettext("Reference:")}</span>
                <span class="font-semibold">CAW-EMMA-0124</span>
              </div>
            </div>
            <:footer>
              <p class={["text-xs", Theme.text_color(:secondary)]}>
                💡 <strong>{gettext("Important:")}</strong>
                {gettext(
                  "Please include the reference code in your transfer to ensure proper allocation."
                )}
              </p>
            </:footer>
          </.info_box>

          <.info_box variant={:neutral} icon="📧" title={gettext("Invoice & Payment Confirmation")}>
            <div class="text-sm space-y-1">
              <p>• {gettext("An invoice will be emailed to you after enrollment completion")}</p>
              <p>• {gettext("Credit card payments are processed immediately")}</p>
              <p>• {gettext("Cash/transfer payments will show as \"Pending\" until received")}</p>
            </div>
          </.info_box>

          <button
            type="submit"
            class={[
              "w-full py-4 text-white",
              Theme.typography(:card_title),
              Theme.rounded(:lg),
              "hover:shadow-lg transform hover:scale-[1.02]",
              Theme.transition(:normal),
              Theme.gradient(:primary)
            ]}
          >
            {gettext("Complete Enrollment")}
          </button>
        </form>
      </div>
    </div>
    """
  end
end
