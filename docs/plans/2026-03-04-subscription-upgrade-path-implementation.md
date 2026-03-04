# Subscription Upgrade Path Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give providers a way to change subscription tiers — both during registration and from a dedicated subscription management page.

**Architecture:** Follows existing DDD/Ports & Adapters pattern. Domain model gets a `change_tier/2` method, new use case orchestrates the update, new LiveView at `/provider/subscription` displays tier cards. Registration form conditionally shows tier selector when provider role is checked, passing tier through the event system.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, existing `pricing_card` component, existing Entitlements module.

---

### Task 1: Domain — Add `change_tier/2` to ProviderProfile

**Files:**
- Modify: `lib/klass_hero/provider/domain/models/provider_profile.ex`
- Test: `test/klass_hero/provider/domain/models/provider_profile_change_tier_test.exs`

**Step 1: Write the failing test**

Create `test/klass_hero/provider/domain/models/provider_profile_change_tier_test.exs`:

```elixir
defmodule KlassHero.Provider.Domain.Models.ProviderProfileChangeTierTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  defp build_profile(tier \\ :starter) do
    {:ok, profile} =
      ProviderProfile.new(%{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        subscription_tier: tier
      })

    profile
  end

  describe "change_tier/2" do
    test "upgrades to a valid tier" do
      profile = build_profile(:starter)
      assert {:ok, updated} = ProviderProfile.change_tier(profile, :professional)
      assert updated.subscription_tier == :professional
    end

    test "downgrades to a valid tier" do
      profile = build_profile(:business_plus)
      assert {:ok, updated} = ProviderProfile.change_tier(profile, :starter)
      assert updated.subscription_tier == :starter
    end

    test "rejects same tier" do
      profile = build_profile(:starter)
      assert {:error, :same_tier} = ProviderProfile.change_tier(profile, :starter)
    end

    test "rejects invalid tier" do
      profile = build_profile(:starter)
      assert {:error, :invalid_tier} = ProviderProfile.change_tier(profile, :gold)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/domain/models/provider_profile_change_tier_test.exs`
Expected: FAIL — `change_tier/2` is undefined

**Step 3: Write minimal implementation**

Add to `lib/klass_hero/provider/domain/models/provider_profile.ex` after the `unverify/1` function (around line 123):

```elixir
@doc """
Changes the subscription tier for a provider profile.

Returns:
- `{:ok, updated_profile}` on success
- `{:error, :same_tier}` if new tier matches current
- `{:error, :invalid_tier}` if tier is not a valid provider tier
"""
def change_tier(%__MODULE__{} = profile, new_tier) when is_atom(new_tier) do
  cond do
    not SubscriptionTiers.valid_provider_tier?(new_tier) ->
      {:error, :invalid_tier}

    profile.subscription_tier == new_tier ->
      {:error, :same_tier}

    true ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, %{profile | subscription_tier: new_tier, updated_at: now}}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/provider/domain/models/provider_profile_change_tier_test.exs`
Expected: PASS (4 tests, 0 failures)

**Step 5: Commit**

```bash
git add lib/klass_hero/provider/domain/models/provider_profile.ex test/klass_hero/provider/domain/models/provider_profile_change_tier_test.exs
git commit -m "feat: add change_tier/2 to ProviderProfile domain model"
```

---

### Task 2: Use Case — ChangeSubscriptionTier

**Files:**
- Create: `lib/klass_hero/provider/application/use_cases/providers/change_subscription_tier.ex`
- Test: `test/klass_hero/provider/application/use_cases/providers/change_subscription_tier_test.exs`

**Step 1: Write the failing test**

Create `test/klass_hero/provider/application/use_cases/providers/change_subscription_tier_test.exs`:

```elixir
defmodule KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTierTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTier
  alias KlassHero.ProviderFixtures

  describe "execute/2" do
    test "changes subscription tier for an existing provider" do
      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "starter")
      assert {:ok, updated} = ChangeSubscriptionTier.execute(provider, :professional)
      assert updated.subscription_tier == :professional
    end

    test "returns error for same tier" do
      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "professional")
      assert {:error, :same_tier} = ChangeSubscriptionTier.execute(provider, :professional)
    end

    test "returns error for invalid tier" do
      provider = ProviderFixtures.provider_profile_fixture()
      assert {:error, :invalid_tier} = ChangeSubscriptionTier.execute(provider, :gold)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/application/use_cases/providers/change_subscription_tier_test.exs`
Expected: FAIL — module does not exist

**Step 3: Write minimal implementation**

Create `lib/klass_hero/provider/application/use_cases/providers/change_subscription_tier.ex`:

```elixir
defmodule KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTier do
  @moduledoc """
  Use case for changing a provider's subscription tier.

  Orchestrates domain validation and persistence through the repository port.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_provider_profiles])

  @doc """
  Changes the subscription tier for a provider profile.

  Returns:
  - `{:ok, ProviderProfile.t()}` on success
  - `{:error, :same_tier}` if new tier matches current
  - `{:error, :invalid_tier}` if tier is not valid
  - `{:error, :not_found}` if provider doesn't exist in DB
  """
  def execute(%ProviderProfile{} = profile, new_tier) when is_atom(new_tier) do
    with {:ok, updated_profile} <- ProviderProfile.change_tier(profile, new_tier),
         {:ok, persisted} <- @repository.update(updated_profile) do
      {:ok, persisted}
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/provider/application/use_cases/providers/change_subscription_tier_test.exs`
Expected: PASS (3 tests, 0 failures)

**Step 5: Commit**

```bash
git add lib/klass_hero/provider/application/use_cases/providers/change_subscription_tier.ex test/klass_hero/provider/application/use_cases/providers/change_subscription_tier_test.exs
git commit -m "feat: add ChangeSubscriptionTier use case"
```

---

### Task 3: Context Facade — Add to Provider module

**Files:**
- Modify: `lib/klass_hero/provider.ex`

**Step 1: Add the facade function**

Add alias after the existing use case aliases (around line 38):

```elixir
alias KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTier
```

Add function in the Provider Profile Functions section (after `update_provider_profile/2`, around line 125):

```elixir
@doc """
Changes the subscription tier for a provider profile.

Returns:
- `{:ok, ProviderProfile.t()}` on success
- `{:error, :same_tier}` if new tier matches current
- `{:error, :invalid_tier}` if tier is not valid
"""
@spec change_subscription_tier(ProviderProfile.t(), atom()) ::
        {:ok, ProviderProfile.t()} | {:error, :same_tier | :invalid_tier | :not_found}
def change_subscription_tier(%ProviderProfile{} = profile, new_tier) when is_atom(new_tier) do
  ChangeSubscriptionTier.execute(profile, new_tier)
end
```

**Step 2: Run existing tests to verify no regressions**

Run: `mix test test/klass_hero/provider/ --max-failures 3`
Expected: All pass

**Step 3: Commit**

```bash
git add lib/klass_hero/provider.ex
git commit -m "feat: add change_subscription_tier/2 to Provider facade"
```

---

### Task 4: Subscription LiveView Page

**Files:**
- Create: `lib/klass_hero_web/live/provider/subscription_live.ex`
- Modify: `lib/klass_hero_web/router.ex` (line 76-90, inside `scope "/provider", Provider`)
- Test: `test/klass_hero_web/live/provider/subscription_live_test.exs`

**Step 1: Add route**

In `lib/klass_hero_web/router.ex`, inside the `scope "/provider", Provider do` block (after line 89, before `end`), add:

```elixir
live "/subscription", SubscriptionLive, :index
```

**Step 2: Write the failing test**

Create `test/klass_hero_web/live/provider/subscription_live_test.exs`:

```elixir
defmodule KlassHeroWeb.Provider.SubscriptionLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_provider

  describe "mount" do
    test "renders subscription page with all three tiers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      assert has_element?(view, "#subscription-page")
      assert has_element?(view, "#tier-starter")
      assert has_element?(view, "#tier-professional")
      assert has_element?(view, "#tier-business_plus")
    end

    test "marks current tier as active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      # Default tier is starter
      assert has_element?(view, "#tier-starter [data-current-plan]")
    end
  end

  describe "switch_tier event" do
    test "switches to professional tier", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      view
      |> element("#switch-to-professional")
      |> render_click()

      assert has_element?(view, "#tier-professional [data-current-plan]")
      assert render(view) =~ "Switched to"
    end

    test "switches to business_plus tier", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      view
      |> element("#switch-to-business_plus")
      |> render_click()

      assert has_element?(view, "#tier-business_plus [data-current-plan]")
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/provider/subscription_live_test.exs`
Expected: FAIL — module does not exist

**Step 4: Write the LiveView implementation**

Create `lib/klass_hero_web/live/provider/subscription_live.ex`:

```elixir
defmodule KlassHeroWeb.Provider.SubscriptionLive do
  @moduledoc """
  Subscription management page for providers.

  Displays all available provider tiers and allows instant switching
  between them. No payment integration (MVP).
  """
  use KlassHeroWeb, :live_view

  alias KlassHero.Entitlements
  alias KlassHero.Provider
  alias KlassHeroWeb.Presenters.ProviderPresenter

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    provider = socket.assigns.current_scope.provider

    {:ok,
     socket
     |> assign(:page_title, gettext("Manage Your Plan"))
     |> assign(:provider, provider)
     |> assign(:current_tier, provider.subscription_tier || :starter)
     |> assign(:tiers, build_tier_data())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="subscription-page" class="max-w-4xl mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-zinc-900">{gettext("Manage Your Plan")}</h1>
        <p class="mt-2 text-zinc-600">
          {gettext("Choose the plan that best fits your needs. Changes take effect immediately.")}
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div :for={tier <- @tiers} id={"tier-#{tier.key}"}>
          <.pricing_card
            title={tier.label}
            subtitle={tier.subtitle}
            price={tier.price}
            period={tier.period}
            features={tier.features}
            popular={tier.key == :professional}
            cta_text={
              if(@current_tier == tier.key,
                do: gettext("Current Plan"),
                else: gettext("Switch to %{plan}", plan: tier.label)
              )
            }
            class={if(@current_tier == tier.key, do: "ring-2 ring-hero-blue-500", else: "")}
          >
            <:action>
              <%= if @current_tier == tier.key do %>
                <button
                  id={"switch-to-#{tier.key}"}
                  data-current-plan
                  disabled
                  class="w-full py-2.5 px-4 rounded-lg bg-zinc-100 text-zinc-400 cursor-not-allowed text-sm font-medium"
                >
                  {gettext("Current Plan")}
                </button>
              <% else %>
                <button
                  id={"switch-to-#{tier.key}"}
                  phx-click="switch_tier"
                  phx-value-tier={tier.key}
                  class="w-full py-2.5 px-4 rounded-lg bg-hero-blue-600 hover:bg-hero-blue-700 text-white text-sm font-medium transition-colors"
                >
                  {gettext("Switch to %{plan}", plan: tier.label)}
                </button>
              <% end %>
            </:action>
          </.pricing_card>
        </div>
      </div>

      <div class="mt-8 text-center">
        <.link navigate={~p"/provider/dashboard"} class="text-sm text-zinc-500 hover:text-zinc-700">
          {gettext("← Back to Dashboard")}
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("switch_tier", %{"tier" => tier_string}, socket) do
    new_tier = String.to_existing_atom(tier_string)

    case Provider.change_subscription_tier(socket.assigns.provider, new_tier) do
      {:ok, updated_provider} ->
        label = ProviderPresenter.tier_label(new_tier)

        {:noreply,
         socket
         |> assign(:provider, updated_provider)
         |> assign(:current_tier, new_tier)
         |> put_flash(:info, gettext("Switched to %{plan}", plan: label))}

      {:error, :same_tier} ->
        {:noreply, put_flash(socket, :info, gettext("You're already on this plan."))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not change plan. Please try again."))}
    end
  end

  defp build_tier_data do
    [
      %{
        key: :starter,
        label: gettext("Starter"),
        subtitle: gettext("Get started with the basics"),
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
        label: gettext("Professional"),
        subtitle: gettext("Grow your business"),
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
        label: gettext("Business Plus"),
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
```

**Important note for implementer:** The `pricing_card` component may not have an `:action` slot. Check `lib/klass_hero_web/components/ui_components.ex` around line 1456. If it doesn't have a slot, the button needs to go outside the component, or the component needs an `:action` slot added. Alternatively, build the tier cards inline without using `pricing_card` — the simplest correct approach given the "current plan" vs "switch" button logic.

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/provider/subscription_live_test.exs`
Expected: PASS (4 tests, 0 failures)

If test failures occur due to `pricing_card` not having an `:action` slot, build the tier cards inline with divs instead.

**Step 6: Commit**

```bash
git add lib/klass_hero_web/live/provider/subscription_live.ex lib/klass_hero_web/router.ex test/klass_hero_web/live/provider/subscription_live_test.exs
git commit -m "feat: add provider subscription management page"
```

---

### Task 5: Dashboard CTA Banner

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Test: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 1: Write the failing test**

Add to `test/klass_hero_web/live/provider/dashboard_live_test.exs`, inside the existing `describe "overview section"` block:

```elixir
test "shows subscription plan management link", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/provider/dashboard")
  assert has_element?(view, "#subscription-cta")
  assert has_element?(view, ~s(a[href="/provider/subscription"]))
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs --max-failures 1`
Expected: FAIL — no element `#subscription-cta`

**Step 3: Add CTA banner to dashboard overview template**

In `lib/klass_hero_web/live/provider/dashboard_live.ex`, find the overview tab render section. Look for the business profile card rendering (search for `business` or `plan_label`). After the business profile card, add:

```heex
<%!-- Subscription CTA --%>
<div id="subscription-cta" class="mt-4 rounded-lg border border-hero-blue-200 bg-hero-blue-50 p-4">
  <div class="flex items-center justify-between">
    <div>
      <p class="text-sm font-medium text-zinc-900">
        {gettext("Current Plan: %{plan}", plan: @business.plan_label)}
      </p>
      <p :if={@business.plan == :starter} class="text-sm text-zinc-600 mt-0.5">
        {gettext("Upgrade your plan to unlock more features")}
      </p>
    </div>
    <.link
      navigate={~p"/provider/subscription"}
      class="text-sm font-medium text-hero-blue-600 hover:text-hero-blue-700 whitespace-nowrap"
    >
      {gettext("Manage Plan →")}
    </.link>
  </div>
</div>
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs --max-failures 1`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex test/klass_hero_web/live/provider/dashboard_live_test.exs
git commit -m "feat: add subscription CTA banner to provider dashboard"
```

---

### Task 6: Registration — Pass Tier Through Event System

This task crosses the Accounts → Provider context boundary. Changes span multiple files.

**Files:**
- Modify: `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex` (line 28-29)
- Modify: `lib/klass_hero/accounts/domain/events/user_events.ex` (line 86-89)
- Modify: `lib/klass_hero/provider/adapters/driven/events/provider_event_handler.ex` (line 53-58)

**Step 1: Add virtual field to User schema**

In `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`, add after line 29 (`field :locale, :string, default: "en"`):

```elixir
field :provider_subscription_tier, :string, virtual: true
```

Update `registration_changeset/3` to cast the new field. Change line 62:

```elixir
|> cast(attrs, [:name, :email, :intended_roles, :provider_subscription_tier])
```

**Step 2: Include tier in domain event payload**

In `lib/klass_hero/accounts/domain/events/user_events.ex`, update `user_registered/3` (around line 86-89) to include the tier. Change the `base_payload`:

```elixir
base_payload = %{
  email: user.email,
  name: user.name,
  intended_roles: Enum.map(Map.get(user, :intended_roles) || [], &Atom.to_string/1),
  provider_subscription_tier: Map.get(user, :provider_subscription_tier)
}
```

**Step 3: Read tier in Provider event handler**

In `lib/klass_hero/provider/adapters/driven/events/provider_event_handler.ex`, update `handle_event` for `:user_registered` (line 37-49) and `create_provider_profile_with_retry` (line 53-69):

```elixir
@impl true
def handle_event(%{event_type: :user_registered, entity_id: user_id, payload: payload}) do
  intended_roles = Map.get(payload, :intended_roles, [])
  business_name = Map.get(payload, :name, "")
  provider_tier = Map.get(payload, :provider_subscription_tier)

  # Trigger: user_registered event with role list
  # Why: only create provider profile if "provider" role requested
  # Outcome: provider profile created with selected tier or default starter
  if "provider" in intended_roles do
    create_provider_profile_with_retry(user_id, business_name, provider_tier)
  else
    :ignore
  end
end
```

Update `create_provider_profile_with_retry`:

```elixir
defp create_provider_profile_with_retry(user_id, business_name, provider_tier) do
  attrs =
    %{
      identity_id: user_id,
      business_name: business_name
    }
    |> maybe_put_tier(provider_tier)

  operation = fn ->
    Provider.create_provider_profile(attrs)
  end

  context = %{
    operation_name: "create provider profile",
    aggregate_id: user_id,
    backoff_ms: 100
  }

  RetryHelpers.retry_with_backoff(operation, context)
end

# Trigger: provider_subscription_tier may be nil or a string like "professional"
# Why: nil means use default (starter); string needs conversion to atom for domain model
# Outcome: attrs includes subscription_tier only when explicitly selected
defp maybe_put_tier(attrs, nil), do: attrs
defp maybe_put_tier(attrs, ""), do: attrs

defp maybe_put_tier(attrs, tier) when is_binary(tier) do
  Map.put(attrs, :subscription_tier, String.to_existing_atom(tier))
end
```

**Step 4: Run full test suite to verify no regressions**

Run: `mix test --max-failures 5`
Expected: All pass

**Step 5: Commit**

```bash
git add lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex lib/klass_hero/accounts/domain/events/user_events.ex lib/klass_hero/provider/adapters/driven/events/provider_event_handler.ex
git commit -m "feat: pass subscription tier through registration event to provider creation"
```

---

### Task 7: Registration — Tier Selector UI

**Files:**
- Modify: `lib/klass_hero_web/live/user_live/registration.ex`
- Test: `test/klass_hero_web/live/user_live/registration_tier_test.exs`

**Step 1: Write the failing test**

Create `test/klass_hero_web/live/user_live/registration_tier_test.exs`:

```elixir
defmodule KlassHeroWeb.UserLive.RegistrationTierTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "tier selector" do
    test "shows tier selector when provider role is checked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      # Initially hidden
      refute has_element?(view, "#tier-selector")

      # Check provider checkbox
      view
      |> form("#registration_form", %{
        "user" => %{
          "name" => "Test",
          "email" => "test@example.com",
          "intended_roles" => ["provider"]
        }
      })
      |> render_change()

      assert has_element?(view, "#tier-selector")
      assert has_element?(view, "#tier-option-starter")
      assert has_element?(view, "#tier-option-professional")
      assert has_element?(view, "#tier-option-business_plus")
    end

    test "hides tier selector when provider role is unchecked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      # Check provider, then uncheck
      view
      |> form("#registration_form", %{
        "user" => %{
          "name" => "Test",
          "email" => "test@example.com",
          "intended_roles" => ["provider"]
        }
      })
      |> render_change()

      assert has_element?(view, "#tier-selector")

      view
      |> form("#registration_form", %{
        "user" => %{
          "name" => "Test",
          "email" => "test@example.com",
          "intended_roles" => ["parent"]
        }
      })
      |> render_change()

      refute has_element?(view, "#tier-selector")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/user_live/registration_tier_test.exs`
Expected: FAIL — `#tier-selector` not found

**Step 3: Add tier selector to registration form**

In `lib/klass_hero_web/live/user_live/registration.ex`:

1. Add an assign for tracking provider selection. In `mount/3`, add `:show_tier_selector` assign:

```elixir
{:ok,
 socket
 |> assign(:show_tier_selector, false)
 |> assign_form(changeset),
 temporary_assigns: [form: nil]}
```

2. Update `handle_event("validate", ...)` to track provider checkbox state:

```elixir
def handle_event("validate", %{"user" => user_params}, socket) do
  changeset = Accounts.change_user_registration(%User{}, user_params, validate_unique: false)

  intended_roles = Map.get(user_params, "intended_roles", [])
  show_tier = "provider" in intended_roles

  {:noreply,
   socket
   |> assign(:show_tier_selector, show_tier)
   |> assign_form(Map.put(changeset, :action, :validate))}
end
```

3. Add tier selector UI in the template, after the `</fieldset>` closing tag for role selection (after the `<.error>` for intended_roles, around line 87):

```heex
<%!-- Provider Tier Selector --%>
<div :if={@show_tier_selector} id="tier-selector" class="mt-4 space-y-2">
  <p class="text-sm font-semibold text-zinc-800">{gettext("Choose your plan")}</p>
  <div class="space-y-2">
    <label
      :for={
        {key, label, summary} <- [
          {"starter", gettext("Starter"), gettext("2 programs, 18% commission")},
          {"professional", gettext("Professional"), gettext("5 programs, 12% commission")},
          {"business_plus", gettext("Business Plus"),
           gettext("Unlimited programs, 8% commission")}
        ]
      }
      id={"tier-option-#{key}"}
      class="flex items-start gap-3 cursor-pointer rounded-lg border border-zinc-200 p-3 hover:border-hero-blue-300 transition-colors"
    >
      <input
        type="radio"
        name="user[provider_subscription_tier]"
        value={key}
        checked={(@form[:provider_subscription_tier].value || "starter") == key}
        class="mt-0.5 text-hero-blue-600 focus:ring-hero-blue-500"
      />
      <div>
        <span class="font-medium text-zinc-900 text-sm">{label}</span>
        <p class="text-xs text-zinc-500">{summary}</p>
      </div>
    </label>
  </div>
</div>
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/user_live/registration_tier_test.exs`
Expected: PASS (2 tests, 0 failures)

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/user_live/registration.ex test/klass_hero_web/live/user_live/registration_tier_test.exs
git commit -m "feat: add tier selector to provider registration flow"
```

---

### Task 8: Full Integration Verification

**Step 1: Run full test suite**

Run: `mix precommit`
Expected: Compilation with zero warnings, format check passes, all tests pass

**Step 2: Fix any issues**

If warnings or test failures, fix them and re-run.

**Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: resolve warnings and test issues from subscription upgrade"
```

**Step 4: Push**

```bash
git push -u origin worktree-feat/262-subscription-upgrade-path
```
