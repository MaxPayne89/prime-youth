defmodule PrimeYouthWeb.BookingLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.BookingComponents
  import PrimeYouthWeb.Live.SampleFixtures

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    # Get current user from scope (requires authentication)
    current_user = socket.assigns.current_scope.user

    # Validate program_id format, fetch program, and check availability
    with {:ok, id_int} <- parse_program_id(program_id),
         {:ok, program} <- fetch_program(id_int),
         :ok <- validate_program_availability(program) do
      socket =
        socket
        |> assign(page_title: "Enrollment - #{program.title}")
        |> assign(current_user: current_user)
        |> assign(program: program)
        |> assign(children: sample_children(:simple))
        |> assign(selected_child_id: "emma")
        |> assign(special_requirements: "")
        |> assign(payment_method: "card")
        |> assign(weekly_fee: 45.00)
        |> assign(weeks_count: 8)
        |> assign(registration_fee: 25.00)
        |> assign(vat_rate: 0.19)
        |> assign(card_fee: 2.50)
        |> calculate_totals()

      {:ok, socket}
    else
      {:error, :invalid_id} ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid program ID")
         |> redirect(to: ~p"/programs")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Program not found")
         |> redirect(to: ~p"/programs")}

      {:error, :no_spots} ->
        # Get program for redirect (safe to use fallback here since we only need ID for redirect)
        program_for_redirect = fetch_program_unsafe(program_id)

        {:ok,
         socket
         |> put_flash(
           :error,
           "Sorry, this program is currently full. Check back later for availability."
         )
         |> redirect(to: ~p"/programs/#{program_for_redirect.id}")}
    end
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if !socket.assigns.current_user, do: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
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
      |> calculate_totals()

    {:noreply, socket}
  end

  @impl true
  def handle_event("complete_enrollment", params, socket) do
    # Validate enrollment data before processing
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

  defp calculate_totals(socket) do
    weekly_fee = socket.assigns.weekly_fee
    registration_fee = socket.assigns.registration_fee
    vat_rate = socket.assigns.vat_rate
    card_fee = socket.assigns.card_fee
    payment_method = socket.assigns.payment_method

    subtotal = weekly_fee + registration_fee
    vat_amount = subtotal * vat_rate
    card_fee_amount = if payment_method == "card", do: card_fee, else: 0.0
    total = subtotal + vat_amount + card_fee_amount

    socket
    |> assign(subtotal: subtotal)
    |> assign(vat_amount: vat_amount)
    |> assign(card_fee_amount: card_fee_amount)
    |> assign(total: total)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400">
      <div class="max-w-4xl mx-auto px-4 py-6">
        <!-- Header -->
        <.page_header
          variant={:gradient}
          show_back_button
          phx-click="back_to_program"
          class="!p-0 !bg-transparent !shadow-none mb-6"
        >
          <:title>
            <h1 class="text-3xl font-bold text-white">Enrollment</h1>
          </:title>
        </.page_header>
        
    <!-- Activity Summary -->
        <div class="mb-6">
          <h3 class="text-white font-semibold mb-3">Activity Summary</h3>
          <div class="bg-white rounded-2xl p-6 shadow-lg">
            <div class="flex gap-4 mb-4">
              <div class={[
                "w-16 h-16 rounded-xl flex items-center justify-center text-3xl",
                @program.gradient_class
              ]}>
                🎨
              </div>
              <div>
                <h4 class="text-lg font-bold text-gray-900 mb-1">{@program.title}</h4>
                <p class="text-sm text-gray-600">Wednesdays 4-6 PM</p>
              </div>
            </div>
            <div class="border-t border-gray-200 pt-4">
              <div class="flex justify-between items-center mb-2">
                <span class="font-semibold text-gray-800">Total Price:</span>
                <span class="text-2xl font-bold text-prime-cyan-400">
                  €{:erlang.float_to_binary(@total, decimals: 2)}
                </span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-600">Duration:</span>
                <span class="text-gray-600">Jan 15 - Mar 15, 2024</span>
              </div>
            </div>
          </div>
          <div class="mt-2">
            <a href="#" class="text-xs text-white/80 hover:text-white underline">
              Add another program
            </a>
          </div>
        </div>
        
    <!-- Enrollment Form -->
        <form phx-submit="complete_enrollment" class="space-y-6">
          <!-- Select Child -->
          <div class="bg-white rounded-2xl p-6 shadow-lg">
            <label class="block text-sm font-semibold text-gray-800 mb-3">Select Child</label>
            <select
              name="child_id"
              class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent"
            >
              <option value="">Select a child</option>
              <option :for={child <- @children} value={child.id}>
                {child.name} (Age {child.age})
              </option>
            </select>
            <div class="mt-2">
              <a href="#" class="text-xs text-gray-500 hover:text-gray-700 underline">
                Add another child
              </a>
            </div>
          </div>
          
    <!-- Special Requirements -->
          <div class="bg-white rounded-2xl p-6 shadow-lg">
            <label for="special-requirements" class="block text-sm font-semibold text-gray-800 mb-3">
              Special Requirements
            </label>
            <textarea
              id="special-requirements"
              name="special_requirements"
              rows="3"
              maxlength="500"
              placeholder="Any allergies, medical conditions, or special instructions..."
              class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent resize-none"
            ></textarea>
            <div class="flex justify-between mt-2">
              <p class="text-xs text-gray-500">
                Optional: Include any important information we should know about your child.
              </p>
              <p class="text-xs text-gray-500">0/500</p>
            </div>
          </div>
          
    <!-- Payment Method -->
          <div class="bg-white rounded-2xl p-6 shadow-lg">
            <fieldset>
              <legend class="block text-sm font-semibold text-gray-800 mb-3">Payment Method</legend>
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
          
    <!-- Payment Summary -->
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
          
    <!-- Bank Transfer Details -->
          <.info_box :if={@payment_method == "transfer"} variant={:info} title="Bank Transfer Details">
            <p class="mb-4">
              Please transfer <strong>€{:erlang.float_to_binary(@total, decimals: 2)}</strong>
              (no card fees) to the following account:
            </p>
            <div class="space-y-2 font-mono text-sm">
              <div class="flex justify-between">
                <span class="text-gray-600">Account Name:</span>
                <span class="font-semibold">Prime Youth Activities Ltd</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">IBAN:</span>
                <span class="font-semibold">IE64 BOFI 9000 1234 5678 90</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">BIC:</span>
                <span class="font-semibold">BOFIIE2D</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">Reference:</span>
                <span class="font-semibold">CAW-EMMA-0124</span>
              </div>
            </div>
            <:footer>
              <p class="text-xs text-gray-600">
                💡 <strong>Important:</strong>
                Please include the reference code in your transfer to ensure proper allocation.
              </p>
            </:footer>
          </.info_box>
          
    <!-- Invoice Information -->
          <.info_box variant={:neutral} icon="📧" title="Invoice & Payment Confirmation">
            <div class="text-sm space-y-1">
              <p>• An invoice will be emailed to you after enrollment completion</p>
              <p>• Credit card payments are processed immediately</p>
              <p>• Cash/transfer payments will show as "Pending" until received</p>
            </div>
          </.info_box>
          
    <!-- Submit Button -->
          <button
            type="submit"
            class="w-full py-4 bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white font-semibold text-lg rounded-xl hover:shadow-lg transform hover:scale-[1.02] transition-all duration-200"
          >
            Complete Enrollment
          </button>
        </form>
      </div>
    </div>
    """
  end

  # Validation helpers
  defp parse_program_id(id_string) do
    case Integer.parse(id_string) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  defp fetch_program(id) do
    case get_program_by_id(id) do
      nil -> {:error, :not_found}
      program -> {:ok, program}
    end
  end

  defp validate_program_availability(%{spots_left: spots_left}) when spots_left > 0, do: :ok
  defp validate_program_availability(_program), do: {:error, :no_spots}

  # Unsafe fetch for redirect purposes only - when we know we need a program ID for redirect
  # but don't want to fail the entire mount
  defp fetch_program_unsafe(program_id) do
    case Integer.parse(program_id) do
      {id, ""} -> get_program_by_id(id) || %{id: program_id}
      _ -> %{id: program_id}
    end
  end

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
end
