defmodule KlassHero.Messaging.Domain.Ports.ForSchedulingEmailJobs do
  @moduledoc """
  Port for scheduling background email processing jobs.

  Decouples use cases from the specific job processing framework (Oban).
  """

  @callback schedule_content_fetch(email_id :: binary(), resend_id :: String.t()) ::
              {:ok, term()} | {:error, term()}

  @callback schedule_reply_delivery(reply_id :: binary()) ::
              {:ok, term()} | {:error, term()}
end
