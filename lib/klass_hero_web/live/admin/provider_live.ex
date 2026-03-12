defmodule KlassHeroWeb.Admin.ProviderLive do
  @moduledoc """
  Backpex LiveResource for managing provider profiles in the admin dashboard.

  Provides index, show, and edit views. Only verified status and
  subscription tier are editable — all other fields are provider-owned.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read + limited edit operations.
  The `on_item_updated/2` callback bridges back into the domain layer
  by publishing integration/domain events that projections depend on.
  """

  # Backpex requires FQ refs in `use` args — alias can't precede `use` per formatter rules
  # credo:disable-for-lines:10 Credo.Check.Design.AliasUsage
  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
      repo: KlassHero.Repo,
      update_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema.admin_changeset/3,
      create_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema.admin_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.DomainEventBus
  alias KlassHero.Shared.IntegrationEventPublishing

  require KlassHeroWeb.BackpexCompat

  @tier_options Enum.map(
                  KlassHero.Shared.SubscriptionTiers.provider_tiers(),
                  fn tier ->
                    label =
                      tier
                      |> Atom.to_string()
                      |> String.replace("_", " ")
                      |> String.split()
                      |> Enum.map_join(" ", &String.capitalize/1)

                    {label, Atom.to_string(tier)}
                  end
                )

  # Trigger: :new and :delete are not valid operations for provider profiles
  # Why: providers create their own profiles; deletion follows GDPR process
  # Outcome: hides "New" button, denies create/delete actions
  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, :delete, _item), do: false
  def can?(_assigns, :index, _item), do: true
  def can?(_assigns, :show, _item), do: true
  def can?(_assigns, :edit, _item), do: true
  def can?(_assigns, _action, _item), do: false

  @impl Backpex.LiveResource
  def filters do
    [verified: %{module: KlassHeroWeb.Admin.Filters.VerifiedFilter}]
  end

  @impl Backpex.LiveResource
  def singular_name, do: "Provider"

  @impl Backpex.LiveResource
  def plural_name, do: "Providers"

  @impl Backpex.LiveResource
  def fields do
    [
      business_name: %{
        module: Backpex.Fields.Text,
        label: "Business Name",
        searchable: true,
        orderable: true,
        readonly: true
      },
      verified: %{
        module: Backpex.Fields.Boolean,
        label: "Verified",
        orderable: true
      },
      subscription_tier: %{
        module: Backpex.Fields.Select,
        label: "Tier",
        orderable: true,
        options: @tier_options
      },
      description: %{
        module: Backpex.Fields.Textarea,
        label: "Description",
        only: [:show],
        readonly: true
      },
      phone: %{
        module: Backpex.Fields.Text,
        label: "Phone",
        only: [:show],
        readonly: true
      },
      website: %{
        module: Backpex.Fields.Text,
        label: "Website",
        only: [:show],
        readonly: true
      },
      address: %{
        module: Backpex.Fields.Text,
        label: "Address",
        only: [:show],
        readonly: true
      },
      categories: %{
        module: Backpex.Fields.Text,
        label: "Categories",
        only: [:show],
        readonly: true,
        render: fn assigns ->
          ~H"""
          <p>{Enum.join(@value || [], ", ")}</p>
          """
        end
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        only: [:index, :show],
        orderable: true
      }
    ]
  end

  # Trigger: Backpex saved a provider profile update
  # Why: admin_changeset bypasses domain use cases; projections (VerifiedProviders,
  #      ProgramListings) subscribe to integration/domain events to stay in sync
  # Outcome: matching events are published so projections update correctly
  KlassHeroWeb.BackpexCompat.override :on_item_updated, 2 do
    @impl Backpex.LiveResource
    def on_item_updated(socket, item) do
      old_item = socket.assigns.item

      maybe_publish_verification_event(old_item, item, socket)
      maybe_dispatch_tier_event(old_item, item)

      socket
    end
  end

  # Trigger: verified status changed between old and new item
  # Why: ProgramCatalog projections listen for provider_verified / provider_unverified
  #      integration events to keep denormalized provider_verified flag in sync
  # Outcome: integration event published to PubSub for cross-context consumption
  defp maybe_publish_verification_event(%{verified: same}, %{verified: same}, _socket), do: :ok

  defp maybe_publish_verification_event(_old, %{verified: true} = item, socket) do
    admin_id = socket.assigns.current_scope.user.id

    IntegrationEvent.new(
      :provider_verified,
      :provider,
      :provider,
      item.id,
      %{
        provider_id: item.id,
        business_name: item.business_name,
        verified_at: item.verified_at,
        admin_id: admin_id
      }
    )
    |> IntegrationEventPublishing.publish()
  end

  defp maybe_publish_verification_event(_old, %{verified: false} = item, socket) do
    admin_id = socket.assigns.current_scope.user.id

    IntegrationEvent.new(
      :provider_unverified,
      :provider,
      :provider,
      item.id,
      %{
        provider_id: item.id,
        business_name: item.business_name,
        admin_id: admin_id
      }
    )
    |> IntegrationEventPublishing.publish()
  end

  # Trigger: subscription tier changed between old and new item
  # Why: ChangeSubscriptionTier use case dispatches a domain event that gets
  #      promoted to an integration event by PromoteIntegrationEvents handler
  # Outcome: domain event dispatched so downstream handlers are notified
  defp maybe_dispatch_tier_event(%{subscription_tier: same}, %{subscription_tier: same}), do: :ok

  defp maybe_dispatch_tier_event(old_item, item) do
    event =
      DomainEvent.new(
        :subscription_tier_changed,
        item.id,
        :provider,
        %{
          provider_id: item.id,
          previous_tier: String.to_existing_atom(old_item.subscription_tier),
          new_tier: String.to_existing_atom(item.subscription_tier)
        }
      )

    DomainEventBus.dispatch(KlassHero.Provider, event)
  end
end
