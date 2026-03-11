defmodule KlassHeroWeb.Admin.Actions.CancelBookingAction do
  @moduledoc """
  Backpex item action for cancelling bookings from the admin dashboard.

  Shows a confirmation modal with consequence warning and requires a
  cancellation reason. Delegates to the CancelEnrollmentByAdmin use case
  which enforces domain lifecycle guards and dispatches events.
  """

  use BackpexWeb, :item_action

  import Ecto.Changeset

  @impl Backpex.ItemAction
  def icon(assigns, _item) do
    ~H"""
    <Backpex.HTML.CoreComponents.icon name="hero-x-circle" class="h-5 w-5 text-red-600" />
    """
  end

  @impl Backpex.ItemAction
  def label(_assigns, _item), do: "Cancel Booking"

  @impl Backpex.ItemAction
  def confirm(_assigns) do
    "This will free the reserved slot and cannot be undone. Are you sure?"
  end

  @impl Backpex.ItemAction
  def confirm_label(_assigns), do: "Cancel Booking"

  @impl Backpex.ItemAction
  def fields do
    [
      reason: %{
        module: Backpex.Fields.Textarea,
        label: "Cancellation Reason",
        type: :string
      }
    ]
  end

  @impl Backpex.ItemAction
  def changeset(change, attrs, _metadata) do
    change
    |> cast(attrs, [:reason])
    |> validate_required([:reason])
    |> validate_length(:reason, min: 1, max: 1000)
  end

  @impl Backpex.ItemAction
  def handle(socket, items, data) do
    admin_id = socket.assigns.current_scope.user.id

    results =
      Enum.map(items, fn item ->
        KlassHero.Enrollment.cancel_enrollment_by_admin(item.id, admin_id, data.reason)
      end)

    # Trigger: check if any cancellation failed
    # Why: some items may be in a non-cancellable state (completed/cancelled)
    # Outcome: flash appropriate success or error message
    errors = Enum.filter(results, &match?({:error, _}, &1))

    socket =
      if errors == [] do
        Phoenix.LiveView.put_flash(socket, :info, "Booking(s) cancelled successfully.")
      else
        Phoenix.LiveView.put_flash(
          socket,
          :error,
          "Some bookings could not be cancelled (already completed or cancelled)."
        )
      end

    {:ok, socket}
  end
end
