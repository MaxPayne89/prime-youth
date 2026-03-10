defmodule KlassHeroWeb.Admin.StaffLive do
  @moduledoc """
  Backpex LiveResource for managing staff members in the admin dashboard.

  Provides index, show, and edit views. Only `active` status is editable —
  all other fields are provider-owned.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read + limited edit operations.
  """

  # Backpex requires FQ refs in `use` args — alias can't precede `use` per formatter rules
  # credo:disable-for-lines:10 Credo.Check.Design.AliasUsage
  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema,
      repo: KlassHero.Repo,
      update_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema.admin_changeset/3,
      # Required by Backpex even though :new is disabled via can?/3
      create_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema.admin_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  # Trigger: :new and :delete are not valid operations for staff members in admin
  # Why: staff members are created/deleted by their providers
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
    [active: %{module: KlassHeroWeb.Admin.Filters.ActiveFilter}]
  end

  @impl Backpex.LiveResource
  def singular_name, do: "Staff Member"

  @impl Backpex.LiveResource
  def plural_name, do: "Staff Members"

  @impl Backpex.LiveResource
  def fields do
    [
      first_name: %{
        module: Backpex.Fields.Text,
        label: "First Name",
        searchable: true,
        orderable: true,
        readonly: true
      },
      last_name: %{
        module: Backpex.Fields.Text,
        label: "Last Name",
        searchable: true,
        orderable: true,
        readonly: true
      },
      provider: %{
        module: Backpex.Fields.BelongsTo,
        label: "Provider",
        display_field: :business_name,
        searchable: true,
        orderable: true,
        only: [:index, :show]
      },
      role: %{
        module: Backpex.Fields.Text,
        label: "Role",
        searchable: true,
        orderable: true,
        readonly: true
      },
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true,
        readonly: true
      },
      active: %{
        module: Backpex.Fields.Boolean,
        label: "Active",
        orderable: true
      },
      bio: %{
        module: Backpex.Fields.Textarea,
        label: "Bio",
        only: [:show],
        readonly: true
      },
      tags: %{
        module: Backpex.Fields.Text,
        label: "Tags",
        only: [:show],
        readonly: true,
        render: fn assigns ->
          ~H"""
          <p>{Enum.join(@value || [], ", ")}</p>
          """
        end
      },
      qualifications: %{
        module: Backpex.Fields.Text,
        label: "Qualifications",
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
