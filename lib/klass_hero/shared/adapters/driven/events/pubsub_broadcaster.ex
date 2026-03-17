defmodule KlassHero.Shared.Adapters.Driven.Events.PubSubBroadcaster do
  @moduledoc """
  Shared PubSub broadcasting logic for event publisher adapters.

  Handles the common broadcast-log-or-error pattern used by both domain
  and integration event publishers. Plain functions — no behaviours,
  no macros.

  ## Options for `broadcast/3`

    * `:config_key` — app config key to read PubSub server from
      (e.g., `:event_publisher` or `:integration_event_publisher`)
    * `:message_tag` — atom tag for the broadcast tuple
      (e.g., `:domain_event` or `:integration_event`)
    * `:log_label` — human label for log messages
      (e.g., `"event"` or `"integration event"`)
    * `:extra_metadata` — additional Logger metadata keyword list
      (e.g., `[aggregate_id: event.aggregate_id]`)
  """

  require Logger

  @type broadcast_opts :: [
          config_key: atom(),
          message_tag: atom(),
          log_label: String.t(),
          extra_metadata: keyword()
        ]

  @doc """
  Broadcasts an event to a PubSub topic and logs the outcome.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec broadcast(map(), String.t(), broadcast_opts()) :: :ok | {:error, term()}
  def broadcast(event, topic, opts) do
    config_key = Keyword.fetch!(opts, :config_key)
    message_tag = Keyword.fetch!(opts, :message_tag)
    log_label = Keyword.fetch!(opts, :log_label)
    extra_metadata = Keyword.get(opts, :extra_metadata, [])

    pubsub = pubsub_server(config_key)

    case Phoenix.PubSub.broadcast(pubsub, topic, {message_tag, event}) do
      :ok ->
        log_event_published(event, topic, log_label, extra_metadata)
        :ok

      {:error, reason} = error ->
        log_publish_error(event, topic, reason, log_label, extra_metadata)
        error
    end
  end

  @doc """
  Reads the PubSub server name from application config.

  Falls back to `KlassHero.PubSub` if not configured.
  """
  @spec pubsub_server(atom()) :: atom()
  def pubsub_server(config_key) do
    Application.get_env(:klass_hero, config_key, [])
    |> Keyword.get(:pubsub, KlassHero.PubSub)
  end

  defp log_event_published(event, topic, label, extra_metadata) do
    Logger.debug(
      "Published #{label} #{event.event_type} (#{event.event_id}) to topic #{topic}",
      [event_id: event.event_id, event_type: event.event_type, topic: topic] ++ extra_metadata
    )
  end

  defp log_publish_error(event, topic, reason, label, extra_metadata) do
    Logger.error(
      "Failed to publish #{label} #{event.event_type} (#{event.event_id}) to topic #{topic}: #{inspect(reason)}",
      [event_id: event.event_id, event_type: event.event_type, topic: topic, error: reason] ++
        extra_metadata
    )
  end
end
