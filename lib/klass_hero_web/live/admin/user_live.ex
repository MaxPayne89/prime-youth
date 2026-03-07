defmodule KlassHeroWeb.Admin.UserLive do
  @moduledoc """
  Backpex LiveResource for managing users in the admin dashboard.

  Provides index, show, and edit views for user management.
  Email is read-only to prevent accidental changes to authentication data.
  """

  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Accounts.User,
      repo: KlassHero.Repo,
      update_changeset: &__MODULE__.update_changeset/3,
      create_changeset: &__MODULE__.update_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  # Trigger: :new route is not defined for user management
  # Why: users register themselves; admins should not create users
  # Outcome: hides the "New User" button on the index page
  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, _action, _item), do: true

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

  @doc """
  Update changeset for admin user edits.

  Only allows changing name and admin status.
  Email changes are blocked via the readonly field config.
  """
  def update_changeset(user, attrs, _metadata) do
    user
    |> Ecto.Changeset.cast(attrs, [:name, :is_admin])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, min: 2, max: 100)
  end
end
