defmodule KlassHero.Accounts.Application.UseCases.ExportUserData do
  @moduledoc """
  Use case for GDPR data export.

  Produces a serializable map of all personal user data.
  """

  @doc """
  Exports all personal data for the given user in GDPR-compliant format.

  Returns a map containing all user data that can be serialized to JSON.
  """
  def execute(%{id: _, email: _, name: _} = user) do
    %{
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      user: %{
        id: user.id,
        email: user.email,
        name: user.name,
        avatar: Map.get(user, :avatar),
        confirmed_at: Map.get(user, :confirmed_at) && DateTime.to_iso8601(user.confirmed_at),
        created_at: Map.get(user, :inserted_at) && DateTime.to_iso8601(user.inserted_at),
        updated_at: Map.get(user, :updated_at) && DateTime.to_iso8601(user.updated_at)
      }
    }
  end
end
