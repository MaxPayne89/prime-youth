defmodule KlassHero.Participation.Domain.Ports.ForManagingBehavioralNotes do
  @moduledoc """
  Repository port for behavioral note persistence.

  ## Expected Return Values

  - `create/1` - Returns `{:ok, note}` or `{:error, :duplicate_note}`
  - `get_by_id/1` - Returns `{:ok, note}` or `{:error, :not_found}`
  - `update/1` - Returns `{:ok, note}` or `{:error, :not_found}`
  - `list_pending_by_parent/1` - Returns list of notes directly
  - `list_approved_by_child/1` - Returns list of notes directly
  - `get_by_participation_record_and_provider/2` - Returns `{:ok, note}` or `{:error, :not_found}`

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Participation.Domain.Models.BehavioralNote

  @doc "Creates behavioral note. Returns `{:error, :duplicate_note}` on unique violation."
  @callback create(BehavioralNote.t()) ::
              {:ok, BehavioralNote.t()} | {:error, :duplicate_note | :validation_failed}

  @doc "Retrieves behavioral note by ID. Returns `{:error, :not_found}` if not found."
  @callback get_by_id(binary()) :: {:ok, BehavioralNote.t()} | {:error, :not_found}

  @doc "Updates existing behavioral note. Returns `{:error, :not_found}` if not found."
  @callback update(BehavioralNote.t()) ::
              {:ok, BehavioralNote.t()} | {:error, :not_found | :validation_failed}

  @doc "Lists pending behavioral notes for a parent, ordered by submitted_at desc."
  @callback list_pending_by_parent(binary()) :: [BehavioralNote.t()]

  @doc "Lists approved behavioral notes for a child, ordered by submitted_at desc."
  @callback list_approved_by_child(binary()) :: [BehavioralNote.t()]

  @doc "Gets note by participation record and provider. Returns `{:error, :not_found}` if not found."
  @callback get_by_participation_record_and_provider(binary(), binary()) ::
              {:ok, BehavioralNote.t()} | {:error, :not_found}

  @doc "Lists notes for multiple participation records by a single provider."
  @callback list_by_records_and_provider([binary()], binary()) :: [BehavioralNote.t()]
end
