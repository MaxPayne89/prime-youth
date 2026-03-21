defmodule KlassHeroWeb.Admin.EmailsLive do
  @moduledoc """
  Admin inbox for inbound emails received via Resend webhooks.

  Provides list/filter, detail with sanitized HTML, and reply functionality.
  """

  use KlassHeroWeb, :live_view

  alias KlassHero.Messaging
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    unread_count = Messaging.count_inbound_emails_by_status(:unread)

    {:ok,
     socket
     |> assign(:fluid?, false)
     |> assign(:live_resource, nil)
     |> assign(:page_title, gettext("Emails"))
     |> assign(:unread_email_count, unread_count)
     |> assign(:status_filter, nil)
     |> assign(:allow_images, false)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    current_url = URI.parse(uri).path

    socket =
      socket
      |> assign(:current_url, current_url)
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Emails"))
    |> load_emails()
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        reader_id = socket.assigns.current_scope.user.id

        case Messaging.get_inbound_email(uuid, mark_read: true, reader_id: reader_id) do
          {:ok, email} ->
            sanitized_html = Messaging.sanitize_email_html(email.body_html, allow_images: false)
            {:ok, replies} = Messaging.list_email_replies(email.id)

            socket
            |> assign(:email, email)
            |> assign(:sanitized_html, sanitized_html)
            |> assign(:replies, replies)
            |> assign(:allow_images, false)
            |> assign(:reply_form, to_form(%{"body" => ""}, as: :reply))
            |> assign(:page_title, email.subject)
            |> assign(:unread_email_count, Messaging.count_inbound_emails_by_status(:unread))

          {:error, :not_found} ->
            socket
            |> put_flash(:error, gettext("Email not found"))
            |> push_navigate(to: ~p"/admin/emails")
        end

      :error ->
        socket
        |> put_flash(:error, gettext("Email not found"))
        |> push_navigate(to: ~p"/admin/emails")
    end
  end

  # -- Event Handlers --

  @valid_status_filters ~w(unread read archived)

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    filter = parse_status_filter(status)

    {:noreply,
     socket
     |> assign(:status_filter, filter)
     |> load_emails()}
  end

  @impl true
  def handle_event("submit_reply", %{"reply" => %{"body" => body}}, socket) do
    trimmed_body = String.trim(body)

    if trimmed_body == "" do
      {:noreply, socket}
    else
      email = socket.assigns.email
      sent_by_id = socket.assigns.current_scope.user.id

      case Messaging.reply_to_inbound_email(email.id, trimmed_body, sent_by_id) do
        {:ok, reply} ->
          {:noreply,
           socket
           |> assign(:reply_form, to_form(%{"body" => ""}, as: :reply))
           |> update(:replies, fn replies -> replies ++ [reply] end)
           |> push_event("clear_message_input", %{})
           |> put_flash(:info, gettext("Reply sent successfully"))}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send reply"))}
      end
    end
  end

  @impl true
  def handle_event("retry_fetch", _params, socket) do
    email = socket.assigns.email
    scheduler = KlassHero.Messaging.Repositories.email_job_scheduler()

    case scheduler.schedule_content_fetch(email.id, email.resend_id) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> assign(:email, %{email | content_status: :pending})
         |> put_flash(:info, gettext("Content fetch retrying..."))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to schedule retry"))}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    email = socket.assigns.email

    case Messaging.update_inbound_email_status(email.id, "archived") do
      {:ok, updated_email} ->
        {:noreply,
         socket
         |> assign(:email, updated_email)
         |> assign(:unread_email_count, Messaging.count_inbound_emails_by_status(:unread))
         |> put_flash(:info, gettext("Email archived"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to archive email"))}
    end
  end

  @impl true
  def handle_event("mark_unread", _params, socket) do
    email = socket.assigns.email

    case Messaging.update_inbound_email_status(email.id, "unread", %{
           read_by_id: nil,
           read_at: nil
         }) do
      {:ok, updated_email} ->
        {:noreply,
         socket
         |> assign(:email, updated_email)
         |> assign(:unread_email_count, Messaging.count_inbound_emails_by_status(:unread))
         |> put_flash(:info, gettext("Email marked as unread"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to mark email as unread"))}
    end
  end

  @impl true
  def handle_event("load_images", _params, socket) do
    email = socket.assigns.email
    sanitized_html = Messaging.sanitize_email_html(email.body_html, allow_images: true)

    {:noreply,
     socket
     |> assign(:allow_images, true)
     |> assign(:sanitized_html, sanitized_html)}
  end

  # -- Private Helpers --

  defp load_emails(socket) do
    opts =
      case socket.assigns.status_filter do
        nil -> []
        status -> [status: status]
      end

    {:ok, emails, _has_more} = Messaging.list_inbound_emails(opts)
    stream(socket, :emails, emails, reset: true)
  end

  defp parse_status_filter(status) when status in @valid_status_filters,
    do: String.to_existing_atom(status)

  defp parse_status_filter(_), do: nil

  defp status_badge_class(:unread), do: "badge-warning"
  defp status_badge_class(:read), do: "badge-ghost"
  defp status_badge_class(:archived), do: "badge-secondary"
  defp status_badge_class(_), do: ""

  defp reply_status_badge_class(:sending), do: "badge-info"
  defp reply_status_badge_class(:sent), do: "badge-success"
  defp reply_status_badge_class(:failed), do: "badge-error"
  defp reply_status_badge_class(_), do: ""

  defp format_received_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %H:%M")
  end

  defp format_received_at(_), do: ""
end
