defmodule KlassHero.Family.Application.Queries.ExportUserData do
  @moduledoc """
  Query for exporting all Family-owned personal data for a user.

  Returns `%{children: [...]}` when the user has a parent profile,
  or `%{}` when no parent profile exists.
  """

  @parent_repository Application.compile_env!(:klass_hero, [
                       :family,
                       :for_storing_parent_profiles
                     ])
  @child_repository Application.compile_env!(:klass_hero, [
                      :family,
                      :for_storing_children
                    ])
  @consent_repository Application.compile_env!(:klass_hero, [
                        :family,
                        :for_storing_consents
                      ])

  @doc """
  Exports all Family-owned personal data for a user.

  Returns:
  - `%{children: [...]}` when the user has a parent profile
  - `%{}` when no parent profile exists
  """
  def execute(identity_id) do
    case @parent_repository.get_by_identity_id(identity_id) do
      {:ok, parent} ->
        children = @child_repository.list_by_guardian(parent.id)

        children_data =
          Enum.map(children, fn child ->
            consents = @consent_repository.list_all_by_child(child.id)
            format_child_export(child, consents)
          end)

        %{children: children_data}

      {:error, :not_found} ->
        %{}
    end
  end

  defp format_child_export(child, consents) do
    %{
      id: child.id,
      first_name: child.first_name,
      last_name: child.last_name,
      date_of_birth: Date.to_iso8601(child.date_of_birth),
      emergency_contact: child.emergency_contact,
      support_needs: child.support_needs,
      allergies: child.allergies,
      created_at: format_datetime(child.inserted_at),
      updated_at: format_datetime(child.updated_at),
      consents: Enum.map(consents, &format_consent_export/1)
    }
  end

  defp format_consent_export(consent) do
    %{
      id: consent.id,
      consent_type: consent.consent_type,
      granted_at: format_datetime(consent.granted_at),
      withdrawn_at: format_datetime(consent.withdrawn_at),
      created_at: format_datetime(consent.inserted_at),
      updated_at: format_datetime(consent.updated_at)
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
