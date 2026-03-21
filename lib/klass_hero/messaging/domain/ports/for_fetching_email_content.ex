defmodule KlassHero.Messaging.Domain.Ports.ForFetchingEmailContent do
  @moduledoc """
  Port for fetching inbound email content from the email provider's API.

  The webhook only delivers metadata; body and headers must be fetched separately.
  """

  @callback fetch_content(resend_email_id :: String.t()) ::
              {:ok, %{html: String.t() | nil, text: String.t() | nil, headers: map()}}
              | {:error, term()}
end
