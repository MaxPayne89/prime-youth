defmodule PrimeYouthWeb.BookingLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    program = get_program_by_id(program_id)

    socket =
      socket
      |> assign(page_title: "Enrollment - #{program.title}")
      |> assign(current_user: sample_user())
      |> assign(program: program)
      |> assign(children: sample_children())
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
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if socket.assigns.current_user, do: nil, else: sample_user()
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
  def handle_event("complete_enrollment", _params, socket) do
    # TODO: Implement enrollment logic
    {:noreply, socket}
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
        <div class="flex items-center gap-4 mb-6">
          <button
            phx-click="back_to_program"
            class="p-2 bg-white/20 backdrop-blur-sm rounded-full hover:bg-white/30 transition-colors"
          >
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 19l-7-7 7-7"
              >
              </path>
            </svg>
          </button>
          <h1 class="text-3xl font-bold text-white">Enrollment</h1>
        </div>

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
                  €<%= :erlang.float_to_binary(@total, decimals: 2) %>
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
                <label class={[
                  "flex items-start gap-3 p-4 border-2 rounded-xl cursor-pointer transition-all",
                  if(@payment_method == "card",
                    do: "border-prime-cyan-400 bg-prime-cyan-50",
                    else: "border-gray-200 hover:border-gray-300"
                  )
                ]}>
                  <input
                    type="radio"
                    name="payment_method"
                    value="card"
                    checked={@payment_method == "card"}
                    phx-click="select_payment_method"
                    phx-value-method="card"
                    class="mt-1"
                  />
                  <div>
                    <div class="font-semibold text-gray-800">Credit Card</div>
                    <div class="text-sm text-gray-600">
                      Pay securely with Visa, Mastercard, or other cards
                    </div>
                  </div>
                </label>

                <label class={[
                  "flex items-start gap-3 p-4 border-2 rounded-xl cursor-pointer transition-all",
                  if(@payment_method == "transfer",
                    do: "border-prime-cyan-400 bg-prime-cyan-50",
                    else: "border-gray-200 hover:border-gray-300"
                  )
                ]}>
                  <input
                    type="radio"
                    name="payment_method"
                    value="transfer"
                    checked={@payment_method == "transfer"}
                    phx-click="select_payment_method"
                    phx-value-method="transfer"
                    class="mt-1"
                  />
                  <div>
                    <div class="font-semibold text-gray-800">Cash / Bank Transfer</div>
                    <div class="text-sm text-gray-600">
                      Avoid card fees - pay cash or direct transfer
                    </div>
                  </div>
                </label>
              </div>
            </fieldset>
          </div>

          <!-- Payment Summary -->
          <div class="bg-white rounded-2xl p-6 shadow-lg">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">Payment Summary</h3>
            <div class="space-y-2">
              <div class="flex justify-between text-gray-700">
                <span>Weekly fee ({@weeks_count} weeks):</span>
                <span>€<%= :erlang.float_to_binary(@weekly_fee, decimals: 2) %></span>
              </div>
              <div class="flex justify-between text-gray-700">
                <span>Registration fee:</span>
                <span>€<%= :erlang.float_to_binary(@registration_fee, decimals: 2) %></span>
              </div>
              <div class="flex justify-between text-gray-700 pb-2 border-b border-gray-200">
                <span>Subtotal:</span>
                <span>€<%= :erlang.float_to_binary(@subtotal, decimals: 2) %></span>
              </div>
              <div class="flex justify-between text-gray-700">
                <span>VAT (19%):</span>
                <span>€<%= :erlang.float_to_binary(@vat_amount, decimals: 2) %></span>
              </div>
              <%= if @payment_method == "card" do %>
                <div class="flex justify-between text-gray-700">
                  <span>Credit card fee:</span>
                  <span>€<%= :erlang.float_to_binary(@card_fee_amount, decimals: 2) %></span>
                </div>
              <% end %>
              <div class="flex justify-between text-lg font-bold pt-2 border-t border-gray-300">
                <span>Total due today:</span>
                <span class="text-prime-cyan-400">€<%= :erlang.float_to_binary(@total, decimals: 2) %></span>
              </div>
            </div>
          </div>

          <!-- Bank Transfer Details -->
          <%= if @payment_method == "transfer" do %>
            <div class="bg-blue-50 border-2 border-blue-200 rounded-2xl p-6 shadow-lg">
              <h3 class="text-lg font-semibold text-gray-800 mb-4">Bank Transfer Details</h3>
              <p class="text-gray-700 mb-4">
                Please transfer
                <strong>€<%= :erlang.float_to_binary(@total, decimals: 2) %></strong>
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
              <div class="mt-4 pt-4 border-t border-blue-300">
                <p class="text-xs text-gray-600">
                  💡 <strong>Important:</strong> Please include the reference code in your transfer to ensure proper allocation.
                </p>
              </div>
            </div>
          <% end %>

          <!-- Invoice Information -->
          <div class="bg-gray-50 border border-gray-200 rounded-2xl p-6 shadow-lg">
            <div class="flex items-start gap-3">
              <div class="text-2xl">📧</div>
              <div>
                <h4 class="font-semibold text-gray-800 mb-2">Invoice & Payment Confirmation</h4>
                <div class="text-sm text-gray-600 space-y-1">
                  <p>• An invoice will be emailed to you after enrollment completion</p>
                  <p>• Credit card payments are processed immediately</p>
                  <p>• Cash/transfer payments will show as "Pending" until received</p>
                </div>
              </div>
            </div>
          </div>

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

  # Sample data
  defp sample_user do
    %{
      name: "Sarah Johnson",
      email: "sarah.johnson@example.com",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face"
    }
  end

  defp sample_children do
    [
      %{id: "emma", name: "Emma Johnson", age: 8},
      %{id: "liam", name: "Liam Johnson", age: 6}
    ]
  end

  defp get_program_by_id("1") do
    %{
      id: "1",
      title: "Creative Art World",
      description: "Unleash your child's creativity through painting, drawing, and sculpture",
      gradient_class: "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600",
      icon_path:
        "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v1.5L15 4l2 7-7 2.5V15a2 2 0 01-2 2z",
      price: 45,
      ages: "6-12",
      duration: "8 weeks",
      schedule: "Wednesdays 4-6 PM",
      spots_left: 3,
      category: "Arts & Crafts"
    }
  end

  defp get_program_by_id("2") do
    %{
      id: "2",
      title: "Chess Masters",
      description: "Learn strategic thinking and problem-solving through chess",
      gradient_class: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
      icon_path:
        "M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z",
      price: 35,
      ages: "7-14",
      duration: "10 weeks",
      schedule: "Tuesdays 3-5 PM",
      spots_left: 5,
      category: "Educational"
    }
  end

  defp get_program_by_id("3") do
    %{
      id: "3",
      title: "Soccer Skills",
      description: "Develop soccer fundamentals in a fun, supportive environment",
      gradient_class: "bg-gradient-to-br from-green-500 via-emerald-600 to-teal-700",
      icon_path:
        "M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z",
      price: 40,
      ages: "5-10",
      duration: "6 weeks",
      schedule: "Saturdays 10 AM-12 PM",
      spots_left: 2,
      category: "Sports"
    }
  end

  defp get_program_by_id(_), do: get_program_by_id("1")
end
