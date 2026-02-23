defmodule KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorker do
  @moduledoc """
  Oban worker that sends a single enrollment invitation email.

  Fetches the invite, builds the email via the configured notifier adapter,
  and transitions the invite status from `pending` to `invite_sent`.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])
  @invite_notifier Application.compile_env!(:klass_hero, [
                     :enrollment,
                     :for_sending_invite_emails
                   ])

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invite_id" => invite_id, "program_name" => program_name}}) do
    case @invite_repository.get_by_id(invite_id) do
      nil ->
        Logger.warning("[SendInviteEmailWorker] Invite not found", invite_id: invite_id)
        {:ok, :not_found}

      # Trigger: invite already processed (not pending)
      # Why: Oban may retry, or event re-dispatched — skip to avoid duplicate emails
      # Outcome: return :skipped without sending
      %{status: status} when status != "pending" ->
        Logger.info("[SendInviteEmailWorker] Skipping non-pending invite",
          invite_id: invite_id,
          status: status
        )

        {:ok, :skipped}

      %{invite_token: nil} ->
        Logger.warning("[SendInviteEmailWorker] Invite has no token", invite_id: invite_id)
        {:error, "invite has no token"}

      invite ->
        send_and_transition(invite, program_name)
    end
  end

  defp send_and_transition(invite, program_name) do
    invite_url = "#{base_url()}/invites/#{invite.invite_token}"

    case @invite_notifier.send_invite(invite, program_name, invite_url) do
      {:ok, _email} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        @invite_repository.transition_status(invite, %{
          status: "invite_sent",
          invite_sent_at: now
        })

      {:error, reason} ->
        Logger.error("[SendInviteEmailWorker] Email delivery failed",
          invite_id: invite.id,
          reason: inspect(reason)
        )

        @invite_repository.transition_status(invite, %{
          status: "failed",
          error_details: "Email delivery failed: #{inspect(reason)}"
        })

        {:error, reason}
    end
  end

  # Trigger: worker needs to build full invite URLs
  # Why: referencing KlassHeroWeb.Endpoint directly violates boundary rules
  # Outcome: reads URL config from application env at runtime instead
  defp base_url do
    endpoint_config = Application.get_env(:klass_hero, KlassHeroWeb.Endpoint, [])
    url_config = Keyword.get(endpoint_config, :url, [])
    scheme = Keyword.get(url_config, :scheme, "http")
    host = Keyword.get(url_config, :host, "localhost")
    port = Keyword.get(url_config, :port)

    case port do
      nil -> "#{scheme}://#{host}"
      443 -> "https://#{host}"
      80 -> "http://#{host}"
      port -> "#{scheme}://#{host}:#{port}"
    end
  end
end
