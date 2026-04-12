defmodule KlassHero.Messaging.Adapters.Driving.Events.StaffAssignmentHandler do
  @moduledoc """
  Handles Provider integration events for staff-program assignment changes.

  On assignment:
  1. Upserts the `program_staff_participants` projection (sets active=true).
  2. Adds the staff user as a participant to all existing active conversations
     for that program (where they are not already a participant).

  On unassignment:
  1. Deactivates the projection entry (sets active=false).
  2. Does NOT remove staff from existing conversations (soft unassign).
  """

  @behaviour KlassHero.Shared.Domain.Ports.Driving.ForHandlingIntegrationEvents

  alias KlassHero.Shared.Adapters.Driven.Events.RetryHelpers

  require Logger

  @conversation_reader Application.compile_env!(:klass_hero, [
                         :messaging,
                         :for_querying_conversations
                       ])
  @participant_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_participants])
  @staff_projection Application.compile_env!(:klass_hero, [
                      :messaging,
                      :for_resolving_program_staff
                    ])

  @impl true
  def subscribed_events, do: [:staff_assigned_to_program, :staff_unassigned_from_program]

  @impl true
  def handle_event(%{event_type: :staff_assigned_to_program, payload: payload}) do
    staff_user_id = Map.get(payload, :staff_user_id)

    if is_nil(staff_user_id) do
      Logger.debug("Skipping staff assignment — no user_id yet",
        staff_member_id: payload.staff_member_id
      )

      :ok
    else
      handle_assignment_with_retry(payload)
    end
  end

  def handle_event(%{event_type: :staff_unassigned_from_program, payload: payload}) do
    handle_unassignment_with_retry(payload)
  end

  def handle_event(_event), do: :ignore

  defp handle_assignment_with_retry(payload) do
    operation = fn ->
      @staff_projection.upsert_active(%{
        provider_id: payload.provider_id,
        program_id: payload.program_id,
        staff_user_id: payload.staff_user_id
      })

      add_staff_to_existing_conversations(payload.program_id, payload.staff_user_id)
      :ok
    end

    context = %{
      operation_name: "handle staff assignment",
      aggregate_id: payload.staff_member_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_and_normalize(operation, context)
  end

  defp handle_unassignment_with_retry(payload) do
    operation = fn ->
      @staff_projection.deactivate(payload.program_id, payload.staff_user_id)
      :ok
    end

    context = %{
      operation_name: "handle staff unassignment",
      aggregate_id: payload.staff_member_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_and_normalize(operation, context)
  end

  defp add_staff_to_existing_conversations(program_id, staff_user_id) do
    conversation_ids =
      @conversation_reader.list_active_program_conversation_ids_without_participant(
        program_id,
        staff_user_id
      )

    {:ok, _count} = @participant_repo.add_to_conversations_batch(staff_user_id, conversation_ids)
  end
end
