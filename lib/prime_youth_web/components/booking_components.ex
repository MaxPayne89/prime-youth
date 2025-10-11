defmodule PrimeYouthWeb.BookingComponents do
  @moduledoc """
  Provides booking and enrollment-specific components for Prime Youth application.

  This module contains domain-specific components related to the booking process,
  payment information, and enrollment confirmations.
  """
  use Phoenix.Component

  @doc """
  Renders an informational box with color variants.

  Supports multiple variants for different message types:
  - `:info` - Blue background for informational content (default)
  - `:neutral` - Gray background for general information
  - `:success` - Green background for success messages
  - `:warning` - Yellow background for warnings
  - `:error` - Red background for errors

  ## Examples

      <.info_box variant={:info} title="Bank Transfer Details">
        <p>Transfer details and instructions...</p>
      </.info_box>

      <.info_box variant={:neutral} icon="📧" title="Invoice Information">
        <ul>
          <li>Point 1</li>
          <li>Point 2</li>
        </ul>
      </.info_box>
  """
  attr :variant, :atom, default: :info, values: [:info, :neutral, :success, :warning, :error]
  attr :title, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true
  slot :footer, doc: "Optional footer content for additional notes or actions"

  def info_box(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl p-6 shadow-lg",
      info_box_styles(@variant),
      @class
    ]}>
      <div class="flex items-start gap-3">
        <div :if={@icon} class="text-2xl">{@icon}</div>
        <div class="flex-1">
          <h3 :if={@title} class="text-lg font-semibold text-gray-800 mb-4">{@title}</h3>
          <div class="text-gray-700">
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
      <div
        :if={@footer != []}
        class={[
          "mt-4 pt-4",
          info_box_footer_border(@variant)
        ]}
      >
        {render_slot(@footer)}
      </div>
    </div>
    """
  end

  defp info_box_styles(:info), do: "bg-blue-50 border-2 border-blue-200"
  defp info_box_styles(:neutral), do: "bg-gray-50 border border-gray-200"
  defp info_box_styles(:success), do: "bg-green-50 border-2 border-green-200"
  defp info_box_styles(:warning), do: "bg-yellow-50 border-2 border-yellow-200"
  defp info_box_styles(:error), do: "bg-red-50 border-2 border-red-200"

  defp info_box_footer_border(:info), do: "border-t border-blue-300"
  defp info_box_footer_border(:neutral), do: "border-t border-gray-300"
  defp info_box_footer_border(:success), do: "border-t border-green-300"
  defp info_box_footer_border(:warning), do: "border-t border-yellow-300"
  defp info_box_footer_border(:error), do: "border-t border-red-300"

  @doc """
  Renders a booking/payment summary card with line items and totals.

  Displays a structured summary of costs with support for:
  - Line items (label + value pairs)
  - Subtotal section with divider
  - Additional fees or charges
  - Grand total with emphasis
  - Conditional items that can be shown/hidden

  ## Examples

      <.booking_summary title="Payment Summary">
        <:line_item label="Weekly fee (8 weeks)" value="€45.00" />
        <:line_item label="Registration fee" value="€25.00" />
        <:subtotal label="Subtotal" value="€70.00" />
        <:line_item label="VAT (19%)" value="€13.30" />
        <:line_item :if={show_card_fee} label="Credit card fee" value="€2.50" />
        <:total label="Total due today" value="€85.80" />
      </.booking_summary>
  """
  attr :title, :string, default: "Summary"
  attr :class, :string, default: ""

  slot :line_item, doc: "Regular line item with label and value" do
    attr :label, :string, required: true
    attr :value, :string, required: true
    attr :after_subtotal, :boolean
  end

  slot :subtotal, doc: "Subtotal line with bottom border" do
    attr :label, :string, required: true
    attr :value, :string, required: true
  end

  slot :total, doc: "Total line with emphasis" do
    attr :label, :string, required: true
    attr :value, :string, required: true
  end

  def booking_summary(assigns) do
    ~H"""
    <div class={["bg-white rounded-2xl p-6 shadow-lg", @class]}>
      <h3 class="text-lg font-semibold text-gray-800 mb-4">{@title}</h3>
      <div class="space-y-2">
        <!-- Regular line items before subtotal -->
        <div
          :for={item <- @line_item}
          :if={!Map.get(item, :after_subtotal, false)}
          class="flex justify-between text-gray-700"
        >
          <span>{item[:label]}</span>
          <span>{item[:value]}</span>
        </div>
        
    <!-- Subtotal with border -->
        <div
          :for={subtotal <- @subtotal}
          class="flex justify-between text-gray-700 pb-2 border-b border-gray-200"
        >
          <span>{subtotal[:label]}</span>
          <span>{subtotal[:value]}</span>
        </div>
        
    <!-- Line items after subtotal (like taxes, fees) -->
        <div
          :for={item <- @line_item}
          :if={Map.get(item, :after_subtotal, false)}
          class="flex justify-between text-gray-700"
        >
          <span>{item[:label]}</span>
          <span>{item[:value]}</span>
        </div>
        
    <!-- Total with emphasis -->
        <div
          :for={total <- @total}
          class="flex justify-between text-lg font-bold pt-2 border-t border-gray-300"
        >
          <span>{total[:label]}</span>
          <span class="text-prime-cyan-400">{total[:value]}</span>
        </div>
      </div>
    </div>
    """
  end
end
