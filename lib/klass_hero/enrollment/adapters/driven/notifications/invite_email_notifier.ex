defmodule KlassHero.Enrollment.Adapters.Driven.Notifications.InviteEmailNotifier do
  @moduledoc """
  Swoosh adapter for sending enrollment invitation emails.

  Composes HTML + plain-text emails and delivers via `KlassHero.Mailer`.
  The guardian receives a link to complete enrollment for their child.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForSendingInviteEmails

  import Swoosh.Email

  alias KlassHero.Mailer

  @from Application.compile_env!(:klass_hero, [:mailer_defaults, :from])

  @impl true
  def send_invite(invite, program_name, invite_url) do
    # Trigger: guardian_first_name may be nil for imported invites without names
    # Why: fall back to the email address so the recipient tuple is always valid
    # Outcome: email.to is [{name_or_email, email}]
    recipient_name = invite.guardian_first_name || invite.guardian_email

    email =
      new()
      |> to({recipient_name, invite.guardian_email})
      |> from(@from)
      |> subject("You're invited to enroll #{invite.child_first_name} in #{program_name}")
      |> text_body(build_text_content(invite, program_name, invite_url))
      |> html_body(build_html_content(invite, program_name, invite_url))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp build_text_content(invite, program_name, invite_url) do
    greeting = invite.guardian_first_name || "there"

    """
    Hi #{greeting},

    You've been invited to enroll #{invite.child_first_name} #{invite.child_last_name} in #{program_name}.

    After clicking the link below, your account will be created automatically.
    You can set a password in your account settings at any time.

    Complete your registration here:
    #{invite_url}

    If you didn't expect this email, you can safely ignore it.

    - The KlassHero Team
    """
  end

  defp build_html_content(invite, program_name, invite_url) do
    greeting = esc(invite.guardian_first_name || "there")
    child_name = "#{esc(invite.child_first_name)} #{esc(invite.child_last_name)}"
    safe_program_name = esc(program_name)
    safe_url = esc(invite_url)

    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #333;">
      <div style="text-align: center; padding: 20px 0; border-bottom: 2px solid #4F46E5;">
        <h1 style="color: #4F46E5; margin: 0; font-size: 24px;">KlassHero</h1>
      </div>
      <div style="padding: 30px 0;">
        <p>Hi #{greeting},</p>
        <p>You've been invited to enroll <strong>#{child_name}</strong> in <strong>#{safe_program_name}</strong>.</p>
        <p style="color: #666; font-size: 14px;">After clicking the link below, your account will be created automatically. You can set a password in your account settings at any time.</p>
        <div style="text-align: center; padding: 20px 0;">
          <a href="#{safe_url}" style="background-color: #4F46E5; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: 600; display: inline-block;">Complete Registration</a>
        </div>
        <p style="color: #666; font-size: 14px;">Or copy this link: #{safe_url}</p>
      </div>
      <div style="border-top: 1px solid #eee; padding-top: 15px; color: #999; font-size: 12px;">
        <p>If you didn't expect this email, you can safely ignore it.</p>
      </div>
    </body>
    </html>
    """
  end

  defp esc(text), do: Plug.HTML.html_escape(to_string(text))
end
