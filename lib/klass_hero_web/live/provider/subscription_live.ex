defmodule KlassHeroWeb.Provider.SubscriptionLive do
  @moduledoc """
  Provider subscription management page.

  Displays all available subscription tiers and allows providers
  to switch between them. Each tier card shows pricing, features,
  and a CTA button (or a "current plan" indicator).
  """
  use KlassHeroWeb, :live_view

  alias KlassHero.Provider
  alias KlassHero.Shared.SubscriptionTiers
  alias KlassHeroWeb.Presenters.ProviderPresenter

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_scope.provider do
      nil ->
        Logger.warning("Subscription page accessed without provider profile",
          user_id: socket.assigns.current_scope.user.id
        )

        {:ok, redirect(socket, to: ~p"/")}

      provider_profile ->
        # Trigger: subscription_tier is nil (data integrity gap)
        # Why: new providers may lack a persisted tier before onboarding completes
        # Outcome: default to :starter so the page renders, log for investigation
        current_tier =
          case provider_profile.subscription_tier do
            nil ->
              Logger.info("Provider missing subscription tier, defaulting to starter",
                provider_id: provider_profile.id
              )

              :starter

            tier ->
              tier
          end

        {:ok,
         socket
         |> assign(:page_title, gettext("Subscription"))
         |> assign(:provider, provider_profile)
         |> assign(:current_tier, current_tier)
         |> assign(:tiers, build_tiers())}
    end
  end

  @impl true
  def handle_event("switch_tier", %{"tier" => tier_string}, socket) do
    case SubscriptionTiers.cast_provider_tier(tier_string) do
      {:ok, new_tier} ->
        provider = socket.assigns.provider

        case Provider.change_subscription_tier(provider, new_tier) do
          {:ok, updated_provider} ->
            label = ProviderPresenter.tier_label(new_tier)

            {:noreply,
             socket
             |> assign(:provider, updated_provider)
             |> assign(:current_tier, new_tier)
             |> put_flash(:info, gettext("Switched to %{plan}", plan: label))}

          {:error, :same_tier} ->
            {:noreply, put_flash(socket, :info, gettext("You are already on this plan"))}

          {:error, :invalid_tier} ->
            {:noreply, put_flash(socket, :error, gettext("Invalid subscription tier"))}

          {:error, reason} ->
            Logger.error("Subscription tier change failed",
              provider_id: provider.id,
              attempted_tier: new_tier,
              reason: inspect(reason)
            )

            {:noreply, put_flash(socket, :error, gettext("Could not change subscription tier"))}
        end

      {:error, :invalid_tier} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid subscription tier"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="subscription-page" class="max-w-5xl mx-auto px-4 py-8">
      <div class="mb-8">
        <.link
          navigate={~p"/provider/dashboard"}
          class="text-hero-blue-600 hover:text-hero-blue-800 text-sm font-medium"
        >
          &larr; {gettext("Back to Dashboard")}
        </.link>
        <h1 class="mt-4 text-2xl font-bold text-gray-900 sm:text-3xl">
          {gettext("Subscription Plans")}
        </h1>
        <p class="mt-2 text-gray-600">
          {gettext("Choose the plan that fits your business needs.")}
        </p>
      </div>

      <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
        <div
          :for={tier <- @tiers}
          id={"tier-#{tier.key}"}
          class={[
            "relative flex flex-col rounded-2xl border-2 bg-white p-6 shadow-sm",
            if(tier.key == @current_tier,
              do: "border-hero-blue-500 ring-2 ring-hero-blue-200",
              else: "border-gray-200"
            )
          ]}
        >
          <%!-- Highlight badge for current plan --%>
          <%= if tier.key == @current_tier do %>
            <div class="absolute -top-3 left-1/2 -translate-x-1/2">
              <span class="inline-flex items-center rounded-full bg-hero-blue-500 px-3 py-0.5 text-xs font-semibold text-white">
                {gettext("Current Plan")}
              </span>
            </div>
          <% end %>

          <div class="mb-4">
            <h2 class="text-lg font-semibold text-gray-900">{tier.title}</h2>
            <p class="mt-1 text-sm text-gray-500">{tier.subtitle}</p>
          </div>

          <div class="mb-6">
            <span class="text-3xl font-bold text-gray-900">{tier.price}</span>
            <span class="text-sm text-gray-500">/{tier.period}</span>
          </div>

          <ul class="mb-8 flex-1 space-y-3">
            <li :for={feature <- tier.features} class="flex items-start gap-2">
              <svg
                class="mt-0.5 h-5 w-5 flex-shrink-0 text-green-500"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="text-sm text-gray-700">{feature}</span>
            </li>
          </ul>

          <%!-- CTA button: disabled for current plan, active for others --%>
          <%= if tier.key == @current_tier do %>
            <button
              id={"switch-to-#{tier.key}"}
              disabled
              data-current-plan
              class="w-full rounded-lg bg-gray-100 px-4 py-2.5 text-sm font-semibold text-gray-400 cursor-not-allowed"
            >
              {gettext("Current Plan")}
            </button>
          <% else %>
            <button
              id={"switch-to-#{tier.key}"}
              phx-click="switch_tier"
              phx-value-tier={tier.key}
              class="w-full rounded-lg bg-hero-blue-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-hero-blue-600 transition-colors"
            >
              {gettext("Switch to %{plan}", plan: tier.title)}
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Builds the static tier data for display.
  # Each map describes one subscription tier's UI card content.
  defp build_tiers do
    [
      %{
        key: :starter,
        title: gettext("Starter"),
        subtitle: gettext("Get started for free"),
        price: gettext("Free"),
        period: gettext("forever"),
        features: [
          gettext("2 programs"),
          gettext("18% commission"),
          gettext("Avatar media only"),
          gettext("1 team seat")
        ]
      },
      %{
        key: :professional,
        title: gettext("Professional"),
        subtitle: gettext("For growing businesses"),
        price: "€19",
        period: gettext("month"),
        features: [
          gettext("5 programs"),
          gettext("12% commission"),
          gettext("Avatar, Gallery & Video"),
          gettext("1 team seat"),
          gettext("Direct messaging")
        ]
      },
      %{
        key: :business_plus,
        title: gettext("Business Plus"),
        subtitle: gettext("For established providers"),
        price: "€49",
        period: gettext("month"),
        features: [
          gettext("Unlimited programs"),
          gettext("8% commission"),
          gettext("All media types"),
          gettext("3 team seats"),
          gettext("Direct messaging"),
          gettext("Promotional content")
        ]
      }
    ]
  end
end
