defmodule KlassHero.Enrollment.Adapters.Driving.Events.EventHandlers.NotifyLiveViews do
  @moduledoc "Delegates Enrollment event notifications to shared NotifyLiveViews handler."

  alias KlassHero.Shared.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
    as: SharedNotifyLiveViews

  defdelegate handle(event), to: SharedNotifyLiveViews
  defdelegate derive_topic(event), to: SharedNotifyLiveViews
  defdelegate build_topic(aggregate_type, event_type), to: SharedNotifyLiveViews
end
