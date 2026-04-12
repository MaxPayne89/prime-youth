defmodule KlassHero.Messaging.Application.Commands.ReplyToEmail do
  @moduledoc """
  Use case for replying to an inbound email.

  Persists the reply record with :sending status and enqueues
  an Oban job for async delivery via Swoosh/Resend.
  """

  require Logger

  @inbound_email_repo Application.compile_env!(:klass_hero, [
                        :messaging,
                        :for_managing_inbound_emails
                      ])
  @email_reply_repo Application.compile_env!(:klass_hero, [
                      :messaging,
                      :for_managing_email_replies
                    ])
  @email_job_scheduler Application.compile_env!(:klass_hero, [
                         :messaging,
                         :for_scheduling_email_jobs
                       ])

  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def execute(email_id, reply_body, sent_by_id, _opts \\ []) do
    with {:ok, _email} <- @inbound_email_repo.get_by_id(email_id),
         {:ok, reply} <-
           @email_reply_repo.create(%{
             inbound_email_id: email_id,
             body: reply_body,
             sent_by_id: sent_by_id
           }),
         {:ok, _job} <- @email_job_scheduler.schedule_reply_delivery(reply.id) do
      Logger.info("Enqueued reply delivery #{reply.id} for email #{email_id}")
      {:ok, reply}
    else
      {:error, :not_found} = error ->
        error

      {:error, %Ecto.Changeset{}} = error ->
        error

      {:error, reason} ->
        Logger.error("Failed to schedule reply delivery: #{inspect(reason)}")
        {:error, :scheduling_failed}
    end
  end
end
