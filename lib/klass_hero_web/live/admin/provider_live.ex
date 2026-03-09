defmodule KlassHeroWeb.Admin.ProviderLive do
  @moduledoc """
  Backpex LiveResource for managing provider profiles in the admin dashboard.

  Provides index, show, and edit views. Only verified status and
  subscription tier are editable — all other fields are provider-owned.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read + limited edit operations.
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
end
