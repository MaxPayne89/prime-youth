defmodule KlassHero.Family.Application.Commands.AnonymizeUserData do
  @moduledoc """
  Command for anonymizing all Family-owned data for a user during GDPR deletion.

  Looks up the user's parent profile, then for each child:
  1. Deletes all consent records
  2. Anonymizes child PII (names, emergency contact, support needs, allergies)
  3. Publishes `child_data_anonymized` event for downstream contexts
  """

  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Family.Domain.Models.Child
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

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
  Anonymizes all Family data for a user.

  Returns:
  - `{:ok, :no_data}` if user has no parent profile
  - `{:ok, %{children_anonymized: count, consents_deleted: count}}`
  """
  def execute(identity_id) do
    case @parent_repository.get_by_identity_id(identity_id) do
      {:ok, parent} ->
        children = @child_repository.list_by_guardian(parent.id)
        anonymize_children_data(children)

      {:error, :not_found} ->
        {:ok, :no_data}
    end
  end

  defp anonymize_children_data(children) do
    anonymized_child_attrs = Child.anonymized_attrs()

    Enum.reduce_while(
      children,
      {:ok, %{children_anonymized: 0, consents_deleted: 0}},
      fn child, {:ok, acc} ->
        with {:ok, consent_count} <- @consent_repository.delete_all_for_child(child.id),
             {:ok, _anonymized_child} <-
               @child_repository.anonymize(child.id, anonymized_child_attrs),
             # Trigger: child PII anonymized and consents deleted
             # Why: downstream contexts own their own child data and must clean it
             # Outcome: Participation context will anonymize behavioral notes
             :ok <- dispatch_child_anonymized(child.id) do
          {:cont,
           {:ok,
            %{
              acc
              | children_anonymized: acc.children_anonymized + 1,
                consents_deleted: acc.consents_deleted + consent_count
            }}}
        else
          {:error, reason} ->
            Logger.error("[Family] anonymize_children_data failed",
              child_id: child.id,
              reason: inspect(reason)
            )

            {:halt, {:error, reason}}
        end
      end
    )
  end

  defp dispatch_child_anonymized(child_id) do
    FamilyEvents.child_data_anonymized(child_id)
    |> EventDispatchHelper.dispatch_or_error(KlassHero.Family)
  end
end
