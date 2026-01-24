defmodule KlassHero.Messaging.Repositories do
  @moduledoc """
  Centralized repository access for Messaging context.

  Provides a single source of truth for repository module resolution,
  eliminating duplicated private functions across use cases.

  ## Usage

      alias KlassHero.Messaging.Repositories

      # Get all repositories at once
      repos = Repositories.all()
      repos.conversations.create(attrs)

      # Or access individually
      Repositories.conversations().create(attrs)
  """

  @doc """
  Returns a map of all repository modules for the messaging context.

  ## Keys

  - `:conversations` - Conversation repository
  - `:messages` - Message repository
  - `:participants` - Participant repository
  - `:enrollments` - Enrollment query adapter
  - `:users` - User resolver adapter
  """
  @spec all() :: %{
          conversations: module(),
          messages: module(),
          participants: module(),
          enrollments: module(),
          users: module()
        }
  def all do
    config = messaging_config()

    %{
      conversations: config[:for_managing_conversations],
      messages: config[:for_managing_messages],
      participants: config[:for_managing_participants],
      enrollments: config[:for_querying_enrollments],
      users: config[:for_resolving_users]
    }
  end

  @doc "Returns the conversation repository module."
  @spec conversations() :: module()
  def conversations, do: messaging_config()[:for_managing_conversations]

  @doc "Returns the message repository module."
  @spec messages() :: module()
  def messages, do: messaging_config()[:for_managing_messages]

  @doc "Returns the participant repository module."
  @spec participants() :: module()
  def participants, do: messaging_config()[:for_managing_participants]

  @doc "Returns the enrollment query adapter module."
  @spec enrollments() :: module()
  def enrollments, do: messaging_config()[:for_querying_enrollments]

  @doc "Returns the user resolver adapter module."
  @spec users() :: module()
  def users, do: messaging_config()[:for_resolving_users]

  @doc "Returns the retention policy configuration."
  @spec retention_config() :: Keyword.t()
  def retention_config, do: messaging_config()[:retention] || []

  defp messaging_config, do: Application.get_env(:klass_hero, :messaging)
end
