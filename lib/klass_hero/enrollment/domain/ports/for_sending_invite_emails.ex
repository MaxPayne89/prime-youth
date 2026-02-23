defmodule KlassHero.Enrollment.Domain.Ports.ForSendingInviteEmails do
  @moduledoc """
  Port for sending enrollment invitation emails.

  Adapters deliver an invite email to the guardian with a link to
  complete enrollment for their child in a specific program.
  """

  @doc """
  Sends an invitation email for the given invite.

  ## Parameters

  - `invite` — struct or map with at least `:guardian_email`,
    `:guardian_first_name`, `:child_first_name`, `:child_last_name`
  - `program_name` — display name of the program
  - `invite_url` — full URL the guardian should visit to accept

  Returns `{:ok, email}` on success or `{:error, reason}` on failure.
  """
  @callback send_invite(invite :: struct() | map(), program_name :: String.t(), invite_url :: String.t()) ::
              {:ok, term()} | {:error, term()}
end
