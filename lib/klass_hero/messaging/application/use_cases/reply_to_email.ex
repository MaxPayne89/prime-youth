defmodule KlassHero.Messaging.Application.UseCases.ReplyToEmail do
  @moduledoc """
  Use case for replying to an inbound email.

  Sends via Swoosh/Resend from the shared configured address.
  Sets In-Reply-To and References headers for email threading.
  """

  alias KlassHero.Messaging.Repositories

  require Logger

  @from Application.compile_env!(:klass_hero, [:mailer_defaults, :from])

  @spec execute(String.t(), String.t(), keyword()) :: {:ok, Swoosh.Email.t()} | {:error, term()}
  def execute(email_id, reply_body, opts \\ []) do
    repo = Repositories.inbound_emails()

    with {:ok, email} <- repo.get_by_id(email_id) do
      from_address = Keyword.get(opts, :from, @from)
      message_id = extract_message_id(email.headers)

      swoosh_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to(email.from_address)
        |> Swoosh.Email.from(from_address)
        |> Swoosh.Email.subject("Re: #{email.subject}")
        |> Swoosh.Email.text_body(reply_body)
        |> maybe_add_threading_headers(message_id)

      case KlassHero.Mailer.deliver(swoosh_email) do
        {:ok, _} ->
          Logger.info("Replied to inbound email #{email_id} to #{email.from_address}")

          {:ok, swoosh_email}

        {:error, reason} ->
          Logger.error("Failed to send reply for #{email_id}: #{inspect(reason)}")

          {:error, reason}
      end
    end
  end

  # Trigger: headers arrive as array of %{"name" => "...", "value" => "..."} from Resend
  # Why: Message-ID needed for proper email threading (In-Reply-To header)
  # Outcome: extracts Message-ID value if present, nil otherwise
  defp extract_message_id(headers) when is_list(headers) do
    Enum.find_value(headers, fn
      %{"name" => "Message-ID", "value" => value} -> value
      %{"name" => "message-id", "value" => value} -> value
      _ -> nil
    end)
  end

  defp extract_message_id(_), do: nil

  # Trigger: no Message-ID found in headers
  # Why: threading headers require a reference ID to be meaningful
  # Outcome: email sent without In-Reply-To/References headers
  defp maybe_add_threading_headers(email, nil), do: email

  defp maybe_add_threading_headers(email, message_id) do
    email
    |> Swoosh.Email.header("In-Reply-To", message_id)
    |> Swoosh.Email.header("References", message_id)
  end
end
