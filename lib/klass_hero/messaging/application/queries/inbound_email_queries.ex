defmodule KlassHero.Messaging.Application.Queries.InboundEmailQueries do
  @moduledoc """
  Queries for inbound email and email reply read operations.
  """

  alias KlassHero.Messaging.Domain.Models.EmailReply

  @inbound_email_repo Application.compile_env!(:klass_hero, [
                        :messaging,
                        :for_managing_inbound_emails
                      ])
  @email_reply_repo Application.compile_env!(:klass_hero, [
                      :messaging,
                      :for_managing_email_replies
                    ])

  @doc """
  Returns the count of inbound emails with the given status.

  ## Parameters
  - status: The status atom (:unread, :read, :archived)

  ## Returns
  - Non-negative integer count
  """
  @spec count_by_status(atom()) :: non_neg_integer()
  def count_by_status(status) do
    @inbound_email_repo.count_by_status(status)
  end

  @doc """
  Lists all email replies for a given inbound email.

  ## Parameters
  - inbound_email_id: The ID of the inbound email

  ## Returns
  - `{:ok, replies}` - List of email replies
  """
  @spec list_replies(String.t()) :: {:ok, [EmailReply.t()]}
  def list_replies(inbound_email_id) do
    @email_reply_repo.list_by_email(inbound_email_id)
  end
end
