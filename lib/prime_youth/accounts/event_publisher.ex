defmodule PrimeYouth.Accounts.EventPublisher do
  @moduledoc """
  Convenience module for publishing Accounts context domain events.

  Provides thin wrappers around the generic event publishing infrastructure
  for user-related events. Uses dependency injection to allow testing with
  mock publishers.

  ## Configuration

  The publisher module is configured in application config:

      config :prime_youth, :event_publisher,
        module: PrimeYouth.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: PrimeYouth.PubSub

  For tests, configure a test publisher:

      config :prime_youth, :event_publisher,
        module: PrimeYouth.Shared.Adapters.Driven.Events.TestEventPublisher,
        pubsub: PrimeYouth.PubSub

  ## Usage

      alias PrimeYouth.Accounts.EventPublisher

      # After successful user registration
      EventPublisher.publish_user_registered(user, registration_source: :web)

      # After email confirmation
      EventPublisher.publish_user_confirmed(user)

      # After email change
      EventPublisher.publish_user_email_changed(user, previous_email: "old@example.com")
  """

  alias PrimeYouth.Accounts.Domain.Events.UserEvents
  alias PrimeYouth.Accounts.User

  @doc """
  Publishes a `user_registered` event.

  This is a critical event that should not be lost.

  ## Parameters

  - `user` - The newly registered User struct
  - `opts` - Options passed to event creation
    - `:registration_source` - Source of registration (:web, :api, :admin, etc.)
    - `:correlation_id` - ID to correlate related events
    - Any other metadata options

  ## Examples

      EventPublisher.publish_user_registered(user, registration_source: :web)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish_user_registered(User, keyword()) :: :ok | {:error, term()}
  def publish_user_registered(%User{} = user, opts \\ []) do
    {payload_opts, meta_opts} = extract_payload_opts(opts, [:registration_source])

    payload = Map.new(payload_opts)

    user
    |> UserEvents.user_registered(payload, meta_opts)
    |> publisher_module().publish()
  end

  @doc """
  Publishes a `user_confirmed` event.

  ## Parameters

  - `user` - The User struct with confirmed_at set
  - `opts` - Options passed to event creation
    - `:confirmation_method` - Method of confirmation (:email_link, :manual, etc.)
    - `:correlation_id` - ID to correlate related events
    - Any other metadata options

  ## Examples

      EventPublisher.publish_user_confirmed(user)
      EventPublisher.publish_user_confirmed(user, confirmation_method: :email_link)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish_user_confirmed(User, keyword()) :: :ok | {:error, term()}
  def publish_user_confirmed(%User{} = user, opts \\ []) do
    {payload_opts, meta_opts} = extract_payload_opts(opts, [:confirmation_method])

    payload = Map.new(payload_opts)

    user
    |> UserEvents.user_confirmed(payload, meta_opts)
    |> publisher_module().publish()
  end

  @doc """
  Publishes a `user_email_changed` event.

  ## Parameters

  - `user` - The User struct with the new email
  - `opts` - Options passed to event creation
    - `:previous_email` - **Required.** The user's previous email address
    - `:correlation_id` - ID to correlate related events
    - Any other metadata options

  ## Examples

      EventPublisher.publish_user_email_changed(user, previous_email: "old@example.com")

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish_user_email_changed(User, keyword()) :: :ok | {:error, term()}
  def publish_user_email_changed(%User{} = user, opts) do
    {payload_opts, meta_opts} = extract_payload_opts(opts, [:previous_email])

    payload = Map.new(payload_opts)

    user
    |> UserEvents.user_email_changed(payload, meta_opts)
    |> publisher_module().publish()
  end

  defp publisher_module do
    Application.get_env(:prime_youth, :event_publisher, [])
    |> Keyword.get(:module, PrimeYouth.Shared.Adapters.Driven.Events.PubSubEventPublisher)
  end

  defp extract_payload_opts(opts, payload_keys) do
    {payload_opts, meta_opts} =
      Enum.split_with(opts, fn {key, _value} ->
        key in payload_keys
      end)

    {payload_opts, meta_opts}
  end
end
