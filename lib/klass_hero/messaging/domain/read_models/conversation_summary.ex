defmodule KlassHero.Messaging.Domain.ReadModels.ConversationSummary do
  @moduledoc """
  Read-optimized DTO for conversation summaries.

  Lightweight struct for inbox display — no business logic.
  Populated from the denormalized conversation_summaries read table.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          conversation_id: String.t(),
          user_id: String.t(),
          conversation_type: String.t(),
          provider_id: String.t(),
          program_id: String.t() | nil,
          subject: String.t() | nil,
          other_participant_name: String.t() | nil,
          participant_count: non_neg_integer(),
          latest_message_content: String.t() | nil,
          latest_message_sender_id: String.t() | nil,
          latest_message_at: DateTime.t() | nil,
          unread_count: non_neg_integer(),
          last_read_at: DateTime.t() | nil,
          archived_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :conversation_id,
    :user_id,
    :conversation_type,
    :provider_id,
    :program_id,
    :subject,
    :other_participant_name,
    :latest_message_content,
    :latest_message_sender_id,
    :latest_message_at,
    :last_read_at,
    :archived_at,
    :inserted_at,
    :updated_at,
    participant_count: 0,
    unread_count: 0
  ]

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end
end
