defmodule KlassHero.Participation.Domain.Events.ParticipationEvents do
  @moduledoc """
  Factory module for creating participation domain events.

  ## Event Types

  - `session_created` - A new program session was created
  - `session_started` - A session has begun
  - `session_completed` - A session has ended
  - `child_checked_in` - A child was checked into a session
  - `child_checked_out` - A child was checked out of a session
  - `child_marked_absent` - A child was marked absent from a session
  - `behavioral_note_submitted` - A behavioral note was submitted for review
  - `behavioral_note_approved` - A behavioral note was approved by a parent
  - `behavioral_note_rejected` - A behavioral note was rejected by a parent

  All events are returned as `DomainEvent` structs.
  """

  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession
  alias KlassHero.Shared.Domain.Events.DomainEvent

  @type behavioral_note_payload :: %{
          note_id: String.t(),
          participation_record_id: String.t(),
          child_id: String.t(),
          provider_id: String.t(),
          parent_id: String.t() | nil
        }

  @aggregate_type :participation

  @doc "Creates a session_created event."
  @spec session_created(ProgramSession.t(), keyword()) :: DomainEvent.t()
  def session_created(%ProgramSession{} = session, opts \\ []) do
    payload = %{
      session_id: session.id,
      program_id: session.program_id,
      session_date: session.session_date,
      start_time: session.start_time,
      end_time: session.end_time,
      location: session.location,
      max_capacity: session.max_capacity
    }

    DomainEvent.new(:session_created, session.id, @aggregate_type, payload, opts)
  end

  @doc "Creates a session_started event."
  @spec session_started(ProgramSession.t(), keyword()) :: DomainEvent.t()
  def session_started(%ProgramSession{} = session, opts \\ []) do
    payload = %{
      session_id: session.id,
      program_id: session.program_id,
      started_at: DateTime.utc_now()
    }

    DomainEvent.new(:session_started, session.id, @aggregate_type, payload, opts)
  end

  @doc "Creates a session_completed event."
  @spec session_completed(ProgramSession.t(), keyword()) :: DomainEvent.t()
  def session_completed(%ProgramSession{} = session, opts \\ []) do
    payload = %{
      session_id: session.id,
      program_id: session.program_id,
      completed_at: DateTime.utc_now()
    }

    DomainEvent.new(:session_completed, session.id, @aggregate_type, payload, opts)
  end

  @doc "Creates a child_checked_in event."
  @spec child_checked_in(ParticipationRecord.t(), keyword()) :: DomainEvent.t()
  def child_checked_in(%ParticipationRecord{} = record, opts \\ []) do
    payload = %{
      record_id: record.id,
      session_id: record.session_id,
      child_id: record.child_id,
      checked_in_by: record.check_in_by,
      checked_in_at: record.check_in_at,
      notes: record.check_in_notes
    }

    DomainEvent.new(:child_checked_in, record.id, @aggregate_type, payload, opts)
  end

  @doc "Creates a child_checked_out event."
  @spec child_checked_out(ParticipationRecord.t(), keyword()) :: DomainEvent.t()
  def child_checked_out(%ParticipationRecord{} = record, opts \\ []) do
    payload = %{
      record_id: record.id,
      session_id: record.session_id,
      child_id: record.child_id,
      checked_out_by: record.check_out_by,
      checked_out_at: record.check_out_at,
      notes: record.check_out_notes
    }

    DomainEvent.new(:child_checked_out, record.id, @aggregate_type, payload, opts)
  end

  @doc "Creates a child_marked_absent event."
  @spec child_marked_absent(ParticipationRecord.t(), keyword()) :: DomainEvent.t()
  def child_marked_absent(%ParticipationRecord{} = record, opts \\ []) do
    payload = %{
      record_id: record.id,
      session_id: record.session_id,
      child_id: record.child_id
    }

    DomainEvent.new(:child_marked_absent, record.id, @aggregate_type, payload, opts)
  end

  @doc "Creates a behavioral_note_submitted event."
  @spec behavioral_note_submitted(BehavioralNote.t(), keyword()) :: DomainEvent.t()
  def behavioral_note_submitted(%BehavioralNote{} = note, opts \\ []) do
    payload = behavioral_note_payload(note)

    DomainEvent.new(:behavioral_note_submitted, note.id, :behavioral_note, payload, opts)
  end

  @doc "Creates a behavioral_note_approved event."
  @spec behavioral_note_approved(BehavioralNote.t(), keyword()) :: DomainEvent.t()
  def behavioral_note_approved(%BehavioralNote{} = note, opts \\ []) do
    payload = behavioral_note_payload(note)

    DomainEvent.new(:behavioral_note_approved, note.id, :behavioral_note, payload, opts)
  end

  @doc "Creates a behavioral_note_rejected event."
  @spec behavioral_note_rejected(BehavioralNote.t(), keyword()) :: DomainEvent.t()
  def behavioral_note_rejected(%BehavioralNote{} = note, opts \\ []) do
    payload = behavioral_note_payload(note)

    DomainEvent.new(:behavioral_note_rejected, note.id, :behavioral_note, payload, opts)
  end

  @spec behavioral_note_payload(BehavioralNote.t()) :: behavioral_note_payload()
  defp behavioral_note_payload(%BehavioralNote{} = note) do
    %{
      note_id: note.id,
      participation_record_id: note.participation_record_id,
      child_id: note.child_id,
      provider_id: note.provider_id,
      parent_id: note.parent_id
    }
  end
end
