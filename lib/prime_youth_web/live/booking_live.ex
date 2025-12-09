defmodule PrimeYouthWeb.BookingLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.BookingComponents

  alias PrimeYouth.Enrollment.Application.UseCases.CalculateEnrollmentFees
  alias PrimeYouth.Family.Application.UseCases.GetChildren
  alias PrimeYouth.ProgramCatalog.Application.UseCases.GetProgramById
  alias PrimeYouthWeb.Theme

  if Mix.env() == :dev do
    use PrimeYouthWeb.DevAuthToggle
  end

  @default_weekly_fee 45.00
  @default_weeks_count 8
  @default_registration_fee 25.00
  @default_vat_rate 0.19
  @default_card_processing_fee 2.50

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    current_user = socket.assigns.current_scope.user

    with {:ok, program} <- fetch_program(program_id),
         :ok <- validate_program_availability(program) do
      {:ok, children} = GetChildren.execute(:simple)

      socket =
        socket
        |> assign(page_title: "Enrollment - #{program.title}")
        |> assign(current_user: current_user)
        |> assign(program: program)
        |> assign(children: children)
        |> assign(selected_child_id: "emma")
        |> assign(special_requirements: "")
        |> assign(payment_method: "card")
        |> assign(weekly_fee: @default_weekly_fee)
        |> assign(weeks_count: @default_weeks_count)
        |> assign(registration_fee: @default_registration_fee)
        |> assign(vat_rate: @default_vat_rate)
        |> assign(card_fee: @default_card_processing_fee)
        |> apply_fee_calculation()

      {:ok, socket}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Program not found")
         |> redirect(to: ~p"/programs")}

      {:error, :no_spots} ->
        program_for_redirect = fetch_program_unsafe(program_id)

        {:ok,
         socket
         |> put_flash(
           :error,
           "Sorry, this program is currently full. Check back later for availability."
         )
         |> redirect(to: ~p"/programs/#{program_for_redirect.id}")}

      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Unable to load program. Please try again later.")
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
  def handle_event("complete_enrollment", params, socket) do
    with :ok <- validate_enrollment_data(socket, params),
         :ok <- validate_payment_method(socket),
         :ok <- validate_program_availability(socket.assigns.program) do
      # TODO: Implement actual enrollment processing:
      # 1. Create enrollment record in database
      # 2. Process payment (if card)
      # 3. Send confirmation email
      # 4. Update program spots_left
      # 5. Return {:ok, enrollment} or {:error, reason}

      {:noreply,
       socket
       |> put_flash(:info, "Enrollment successful! You'll receive a confirmation email shortly.")
       |> push_navigate(to: ~p"/dashboard")}
    else
      {:error, :no_spots} ->
        {:noreply,
         socket
         |> put_flash(:error, "Sorry, this program is now full. Please choose another program.")
         |> push_navigate(to: ~p"/programs")}

      {:error, :invalid_payment} ->
        {:noreply,
         put_flash(socket, :error, "Payment information is invalid. Please check your details.")}

      {:error, :child_not_selected} ->
        {:noreply, put_flash(socket, :error, "Please select a child for enrollment.")}

      {:error, :processing_failed} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Enrollment failed. Please try again or contact support."
         )}
    end
  end

  defp fetch_program(id) do
    GetProgramById.execute(id)
  end

  defp fetch_program_unsafe(program_id) do
    case GetProgramById.execute(program_id) do
      {:ok, program} -> program
      {:error, _} -> %{id: program_id}
    end
  end

  defp apply_fee_calculation(socket) do
    {:ok, fees} =
      CalculateEnrollmentFees.execute(%{
        weekly_fee: socket.assigns.weekly_fee,
        registration_fee: socket.assigns.registration_fee,
        vat_rate: socket.assigns.vat_rate,
        card_fee: socket.assigns.card_fee,
        payment_method: socket.assigns.payment_method
      })

    socket
    |> assign(subtotal: fees.subtotal)
    |> assign(vat_amount: fees.vat_amount)
    |> assign(card_fee_amount: fees.card_fee_amount)
    |> assign(total: fees.total)
  end

  defp validate_program_availability(%{spots_available: spots_available})
       when spots_available > 0, do: :ok

  defp validate_program_availability(_program), do: {:error, :no_spots}

  defp validate_enrollment_data(_socket, params) do
    if is_nil(params["child_id"]) or params["child_id"] == "" do
      {:error, :child_not_selected}
    else
      :ok
    end
  end

  defp validate_payment_method(socket) do
    case socket.assigns.payment_method do
      method when method in ["card", "transfer"] -> :ok
      _ -> {:error, :invalid_payment}
    end
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
            <h1 class={[Theme.typography(:page_title), "text-white"]}>Enrollment</h1>
          </:title>
        </.page_header>

        <div class="mb-6">
          <h3 class="text-white font-semibold mb-3">Activity Summary</h3>
          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <div class="flex gap-4 mb-4">
              <div class={[
                "w-16 h-16 flex items-center justify-center text-3xl",
                Theme.rounded(:lg),
                @program.gradient_class
              ]}>
                🎨
              </div>
              <div>
                <h4 class={[Theme.typography(:card_title), "mb-1", Theme.text_color(:heading)]}>
                  {@program.title}
                </h4>
                <p class={["text-sm", Theme.text_color(:secondary)]}>Wednesdays 4-6 PM</p>
              </div>
            </div>
            <div class={["border-t pt-4", Theme.border_color(:medium)]}>
              <div class="flex justify-between items-center mb-2">
                <span class={["font-semibold", Theme.text_color(:body)]}>Total Price:</span>
                <span class={[Theme.typography(:section_title), Theme.text_color(:primary)]}>
                  €{:erlang.float_to_binary(@total, decimals: 2)}
                </span>
              </div>
              <div class="flex justify-between text-sm">
                <span class={Theme.text_color(:secondary)}>Duration:</span>
                <span class={Theme.text_color(:secondary)}>Jan 15 - Mar 15, 2024</span>
              </div>
            </div>
          </div>
          <div class="mt-2">
            <a href="#" class="text-xs text-white/80 hover:text-white underline">
              Add another program
            </a>
          </div>
        </div>

        <form phx-submit="complete_enrollment" class="space-y-6">
          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <label class={["block text-sm font-semibold mb-3", Theme.text_color(:body)]}>
              Select Child
            </label>
            <select
              name="child_id"
              class={[
                "w-full px-4 py-3 border border-gray-300 focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent",
                Theme.rounded(:lg)
              ]}
            >
              <option value="">Select a child</option>
              <option :for={child <- @children} value={child.id}>
                {child.name} (Age {child.age})
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
                Add another child
              </a>
            </div>
          </div>

          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <label
              for="special-requirements"
              class={["block text-sm font-semibold mb-3", Theme.text_color(:body)]}
            >
              Special Requirements
            </label>
            <textarea
              id="special-requirements"
              name="special_requirements"
              rows="3"
              maxlength="500"
              placeholder="Any allergies, medical conditions, or special instructions..."
              class={[
                "w-full px-4 py-3 border border-gray-300 focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent resize-none",
                Theme.rounded(:lg)
              ]}
            ></textarea>
            <div class="flex justify-between mt-2">
              <p class={["text-xs", Theme.text_color(:muted)]}>
                Optional: Include any important information we should know about your child.
              </p>
              <p class={["text-xs", Theme.text_color(:muted)]}>0/500</p>
            </div>
          </div>

          <div class={[Theme.bg(:surface), Theme.rounded(:xl), "p-6 shadow-lg"]}>
            <fieldset>
              <legend class={["block text-sm font-semibold mb-3", Theme.text_color(:body)]}>
                Payment Method
              </legend>
              <div class="space-y-3">
                <.payment_option
                  value="card"
                  title="Credit Card"
                  description="Pay securely with Visa, Mastercard, or other cards"
                  selected={@payment_method == "card"}
                  phx-click="select_payment_method"
                  phx-value-method="card"
                />

                <.payment_option
                  value="transfer"
                  title="Cash / Bank Transfer"
                  description="Avoid card fees - pay cash or direct transfer"
                  selected={@payment_method == "transfer"}
                  phx-click="select_payment_method"
                  phx-value-method="transfer"
                />
              </div>
            </fieldset>
          </div>

          <.booking_summary title="Payment Summary">
            <:line_item
              label={"Weekly fee (#{@weeks_count} weeks):"}
              value={"€#{:erlang.float_to_binary(@weekly_fee, decimals: 2)}"}
            />
            <:line_item
              label="Registration fee:"
              value={"€#{:erlang.float_to_binary(@registration_fee, decimals: 2)}"}
            />
            <:subtotal
              label="Subtotal:"
              value={"€#{:erlang.float_to_binary(@subtotal, decimals: 2)}"}
            />
            <:line_item
              label="VAT (19%):"
              value={"€#{:erlang.float_to_binary(@vat_amount, decimals: 2)}"}
              after_subtotal={true}
            />
            <:line_item
              :if={@payment_method == "card"}
              label="Credit card fee:"
              value={"€#{:erlang.float_to_binary(@card_fee_amount, decimals: 2)}"}
              after_subtotal={true}
            />
            <:total
              label="Total due today:"
              value={"€#{:erlang.float_to_binary(@total, decimals: 2)}"}
            />
          </.booking_summary>

          <.info_box :if={@payment_method == "transfer"} variant={:info} title="Bank Transfer Details">
            <p class="mb-4">
              Please transfer <strong>€{:erlang.float_to_binary(@total, decimals: 2)}</strong>
              (no card fees) to the following account:
            </p>
            <div class="space-y-2 font-mono text-sm">
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>Account Name:</span>
                <span class="font-semibold">Prime Youth Activities Ltd</span>
              </div>
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>IBAN:</span>
                <span class="font-semibold">IE64 BOFI 9000 1234 5678 90</span>
              </div>
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>BIC:</span>
                <span class="font-semibold">BOFIIE2D</span>
              </div>
              <div class="flex justify-between">
                <span class={Theme.text_color(:secondary)}>Reference:</span>
                <span class="font-semibold">CAW-EMMA-0124</span>
              </div>
            </div>
            <:footer>
              <p class={["text-xs", Theme.text_color(:secondary)]}>
                💡 <strong>Important:</strong>
                Please include the reference code in your transfer to ensure proper allocation.
              </p>
            </:footer>
          </.info_box>

          <.info_box variant={:neutral} icon="📧" title="Invoice & Payment Confirmation">
            <div class="text-sm space-y-1">
              <p>• An invoice will be emailed to you after enrollment completion</p>
              <p>• Credit card payments are processed immediately</p>
              <p>• Cash/transfer payments will show as "Pending" until received</p>
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
            Complete Enrollment
          </button>
        </form>
      </div>
    </div>
    """
  end
end
