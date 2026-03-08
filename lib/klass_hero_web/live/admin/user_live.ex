defmodule KlassHeroWeb.Admin.UserLive do
  @moduledoc """
  Backpex LiveResource for managing users in the admin dashboard.

  Provides index, show, and edit views for user management.
  Creation and deletion are intentionally disabled — users register
  themselves, and account deletion follows the GDPR anonymization flow.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read + limited edit operations.
  """

  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Accounts.User,
      repo: KlassHero.Repo,
      update_changeset: &KlassHero.Accounts.User.admin_update_changeset/3,
      # Required by Backpex even though :new is disabled via can?/3
      create_changeset: &KlassHero.Accounts.User.admin_update_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  # Trigger: :new and :delete are not defined for user management
  # Why: users register themselves; deletion follows GDPR anonymization
  # Outcome: hides "New User" button, denies unknown future actions
  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, :index, _item), do: true
  def can?(_assigns, :show, _item), do: true
  def can?(_assigns, :edit, _item), do: true
  def can?(_assigns, _action, _item), do: false

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def fields do
    [
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true,
        orderable: true,
        readonly: true
      },
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        orderable: true
      },
      is_admin: %{
        module: Backpex.Fields.Boolean,
        label: "Admin",
        orderable: true
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
