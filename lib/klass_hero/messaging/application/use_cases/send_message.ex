defmodule KlassHero.Messaging.Application.UseCases.SendMessage do
  @moduledoc """
  Use case for sending a message in a conversation.

  This use case:
  1. Validates that content or attachments are present
  2. Validates attachment files against domain model rules (type, size, count)
  3. Verifies the sender is a participant in the conversation
  4. Verifies broadcast send permission
  5. Uploads attachment files to S3
  6. Creates the message and persists attachments
  7. Cleans up S3 files on DB failure
  8. Updates the sender's last_read_at (they've seen what they sent)
  9. Publishes a message_sent event with attachment metadata
  """

  alias KlassHero.Messaging.Application.UseCases.Shared
  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Messaging.Domain.Models.Attachment
  alias KlassHero.Messaging.Domain.Models.Message
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus
  alias KlassHero.Shared.Storage

  require Logger

  @context KlassHero.Messaging
  @conversation_repo Application.compile_env!(:klass_hero, [
                       :messaging,
                       :for_managing_conversations
                     ])
  @message_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_messages])
  @participant_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_participants])
  @attachment_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_attachments])
  @user_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_users])
  @staff_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_program_staff])

  @doc """
  Sends a message to a conversation.

  ## Parameters
  - conversation_id: The conversation to send to
  - sender_id: The user sending the message
  - content: The message content (string or nil when attachments present)
  - opts: Optional parameters
    - message_type: :text (default) or :system
    - conversation: pre-fetched %Conversation{} domain struct for the same
      conversation_id (skips DB fetch in broadcast permission check; ignored
      if ID doesn't match)
    - attachments: list of `%{binary: <<>>, filename: "x.jpg", content_type: "image/jpeg", size: 1000}`

  ## Returns
  - `{:ok, message}` - Message sent successfully (with attachments populated)
  - `{:error, :empty_message}` - Neither content nor attachments provided
  - `{:error, :invalid_attachments}` - Attachment validation failed
  - `{:error, :not_participant}` - Sender is not in the conversation
  - `{:error, reason}` - Other errors
  """
  @spec execute(String.t(), String.t(), String.t() | nil, keyword()) ::
          {:ok, Message.t()}
          | {:error, :empty_message | :invalid_attachments | :not_participant | :broadcast_reply_not_allowed | term()}
  def execute(conversation_id, sender_id, content, opts \\ []) do
    message_type = Keyword.get(opts, :message_type, :text)
    conversation = Keyword.get(opts, :conversation)
    attachment_files = Keyword.get(opts, :attachments, [])
    trimmed_content = trim_content(content)

    with :ok <- validate_message_content(trimmed_content, attachment_files),
         :ok <- validate_attachment_files(attachment_files),
         :ok <- Shared.verify_participant(conversation_id, sender_id, @participant_repo),
         :ok <- verify_broadcast_send_permission(conversation_id, sender_id, conversation),
         {:ok, uploaded_files} <- upload_files(attachment_files, conversation_id),
         {:ok, message_with_attachments} <-
           persist_message_and_attachments(
             conversation_id,
             sender_id,
             trimmed_content,
             message_type,
             uploaded_files
           ) do
      update_sender_read_status(conversation_id, sender_id)
      publish_event(message_with_attachments)

      Logger.info("Message sent",
        message_id: message_with_attachments.id,
        conversation_id: conversation_id,
        sender_id: sender_id
      )

      {:ok, message_with_attachments}
    end
  end

  # --- Content and attachment validation ---

  defp trim_content(content) when is_binary(content), do: String.trim(content)
  defp trim_content(nil), do: nil

  defp validate_message_content(nil, []), do: {:error, :empty_message}
  defp validate_message_content("", []), do: {:error, :empty_message}
  defp validate_message_content(_content, _attachments), do: :ok

  defp validate_attachment_files([]), do: :ok

  defp validate_attachment_files(files) do
    cond do
      length(files) > Attachment.max_per_message() ->
        {:error, :invalid_attachments}

      Enum.any?(files, fn f -> f.content_type not in Attachment.allowed_content_types() end) ->
        {:error, :invalid_attachments}

      Enum.any?(files, fn f -> f.size > Attachment.max_file_size_bytes() end) ->
        {:error, :invalid_attachments}

      true ->
        :ok
    end
  end

  # --- S3 upload ---

  defp upload_files([], _conversation_id), do: {:ok, []}

  defp upload_files(files, conversation_id) do
    results =
      files
      |> Task.async_stream(
        fn file ->
          ext = Path.extname(file.filename)
          uuid = Ecto.UUID.generate()
          path = "messaging/attachments/#{conversation_id}/#{uuid}#{ext}"

          case Storage.upload(:public, path, file.binary, content_type: file.content_type) do
            {:ok, url} ->
              {:ok,
               %{
                 file_url: url,
                 original_filename: file.filename,
                 content_type: file.content_type,
                 file_size_bytes: file.size
               }}

            {:error, reason} ->
              {:error, reason}
          end
        end,
        timeout: :infinity
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> {:error, {:task_crashed, reason}}
      end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    case failures do
      [] ->
        {:ok, Enum.map(successes, fn {:ok, uploaded} -> uploaded end)}

      [{:error, reason} | _] ->
        uploaded = Enum.map(successes, fn {:ok, uploaded} -> uploaded end)
        cleanup_uploaded_files(uploaded)

        Logger.error("Failed to upload attachment",
          conversation_id: conversation_id,
          reason: inspect(reason)
        )

        {:error, :upload_failed}
    end
  end

  # --- Persist message + attachments ---

  defp persist_message_and_attachments(conversation_id, sender_id, content, message_type, uploaded_files) do
    message_attrs = %{
      conversation_id: conversation_id,
      sender_id: sender_id,
      content: content,
      message_type: message_type
    }

    result =
      Repo.transaction(fn ->
        with {:ok, message} <- @message_repo.create(message_attrs),
             {:ok, attachments} <- create_attachments(message.id, uploaded_files) do
          %{message | attachments: attachments}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, message_with_attachments} ->
        {:ok, message_with_attachments}

      {:error, reason} ->
        cleanup_uploaded_files(uploaded_files)

        Logger.error("Failed to persist message with attachments, cleaning up S3 files",
          conversation_id: conversation_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp create_attachments(_message_id, []), do: {:ok, []}

  defp create_attachments(message_id, uploaded_files) do
    attrs_list =
      Enum.map(uploaded_files, fn file ->
        Map.put(file, :message_id, message_id)
      end)

    @attachment_repo.create_many(attrs_list)
  end

  # --- Cleanup ---

  defp cleanup_uploaded_files([]), do: :ok

  defp cleanup_uploaded_files(uploaded_files) do
    Enum.each(uploaded_files, fn file ->
      case Storage.delete(:public, file.file_url) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to clean up S3 file",
            file_url: file.file_url,
            reason: inspect(reason)
          )
      end
    end)
  end

  # --- Broadcast permission ---

  # Trigger: sender is trying to post in a broadcast conversation
  # Why: broadcast conversations are one-way — only the provider owner and assigned staff
  #      can send. Parents replying would expose their messages to all other parents
  #      (privacy breach).
  # Outcome: non-provider, non-staff senders are rejected; direct conversations pass through.
  defp verify_broadcast_send_permission(conversation_id, sender_id, conversation) do
    # Trigger: caller may pass a pre-fetched conversation to skip DB round-trip
    # Why: must validate conversation.id matches conversation_id to prevent
    #      a mismatched struct from bypassing broadcast guards (privacy breach)
    # Outcome: uses passed conversation only if ID matches; otherwise fetches from DB
    result =
      if conversation && conversation.id == conversation_id,
        do: {:ok, conversation},
        else: @conversation_repo.get_by_id(conversation_id)

    case result do
      {:ok, %{type: :program_broadcast, provider_id: provider_id, program_id: program_id}} ->
        cond do
          provider_owner?(provider_id, sender_id) -> :ok
          staff_assigned?(program_id, sender_id) -> :ok
          true -> {:error, :broadcast_reply_not_allowed}
        end

      {:ok, _direct_conversation} ->
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp provider_owner?(provider_id, sender_id) do
    case @user_resolver.get_user_id_for_provider(provider_id) do
      {:ok, ^sender_id} -> true
      _ -> false
    end
  end

  defp staff_assigned?(nil, _sender_id), do: false

  defp staff_assigned?(program_id, sender_id) do
    staff_user_ids = @staff_resolver.get_active_staff_user_ids(program_id)
    sender_id in staff_user_ids
  end

  # --- Read status ---

  defp update_sender_read_status(conversation_id, sender_id) do
    now = DateTime.utc_now()

    case @participant_repo.mark_as_read(conversation_id, sender_id, now) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to update sender read status",
          conversation_id: conversation_id,
          sender_id: sender_id,
          reason: inspect(reason)
        )

        :ok
    end
  end

  # --- Event publishing ---

  defp publish_event(message) do
    event =
      MessagingEvents.message_sent(
        message.conversation_id,
        message.id,
        message.sender_id,
        message.content,
        message.message_type,
        message.inserted_at,
        message.attachments
      )

    DomainEventBus.dispatch(@context, event)
    :ok
  end
end
