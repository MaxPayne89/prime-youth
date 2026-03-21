defmodule KlassHero.Messaging.Adapters.Driven.ObanEmailJobScheduler do
  @moduledoc """
  Oban-based implementation of the job scheduling port.

  Translates domain scheduling requests into Oban job insertions.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForSchedulingEmailJobs

  alias KlassHero.Messaging.Workers.{FetchEmailContentWorker, SendEmailReplyWorker}

  @impl true
  def schedule_content_fetch(email_id, resend_id) do
    %{email_id: email_id, resend_id: resend_id}
    |> FetchEmailContentWorker.new()
    |> Oban.insert()
  end

  @impl true
  def schedule_reply_delivery(reply_id) do
    %{reply_id: reply_id}
    |> SendEmailReplyWorker.new()
    |> Oban.insert()
  end
end
