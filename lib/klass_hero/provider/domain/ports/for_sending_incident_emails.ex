defmodule KlassHero.Provider.Domain.Ports.ForSendingIncidentEmails do
  @moduledoc """
  Port for sending incident-report notification emails to a provider's
  business owner.

  Adapters deliver an email summarising the incident — category,
  severity, program, occurrence time, description, and (when available)
  a temporary signed link to the attached photo.
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport

  @typedoc """
  Recipient details. `name` may be nil for legacy rows whose owner has
  no display name on record; the adapter falls back to the email
  address in that case.
  """
  @type recipient :: %{required(:email) => String.t(), required(:name) => String.t() | nil}

  @typedoc """
  Display context resolved by the use case before calling the notifier.
  Keeps the adapter free of port lookups and translation concerns.
  """
  @type context :: %{
          required(:program_name) => String.t(),
          required(:business_name) => String.t() | nil,
          required(:signed_photo_url) => String.t() | nil
        }

  @doc """
  Sends an incident-report email to the given recipient.

  Returns `{:ok, email}` on successful delivery, or `{:error, reason}`
  on transient/permanent mailer failure (callers — typically an Oban
  worker — decide whether to retry).
  """
  @callback send_incident_report(recipient(), IncidentReport.t(), context()) ::
              {:ok, term()} | {:error, term()}
end
