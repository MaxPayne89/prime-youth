defmodule PrimeYouth.Shared.Adapters.Driven.Events.EventTopics do
  @moduledoc """
  Helper module for working with event topics.

  Provides functions for building topic names and getting all topics
  for a given aggregate type.

  ## Topic Convention

  Topics follow the format: `{aggregate_type}:{event_type}`

  Examples:
  - `user:user_registered`
  - `enrollment:enrollment_confirmed`
  - `program:program_updated`
  """

  @doc """
  Builds a topic string from aggregate type and event type.

  ## Examples

      iex> EventTopics.build(:user, :user_registered)
      "user:user_registered"

      iex> EventTopics.build(:enrollment, :enrollment_confirmed)
      "enrollment:enrollment_confirmed"
  """
  @spec build(atom(), atom()) :: String.t()
  def build(aggregate_type, event_type) do
    "#{aggregate_type}:#{event_type}"
  end

  @doc """
  Returns all known event topics for a given aggregate type.

  Useful for subscribing to all events of a particular aggregate.
  Add new events here as they are created.

  ## Examples

      iex> EventTopics.topics_for_aggregate(:user)
      ["user:user_registered", "user:user_confirmed", "user:user_email_changed", "user:user_anonymized"]
  """
  @spec topics_for_aggregate(atom()) :: [String.t()]
  def topics_for_aggregate(:user) do
    [
      "user:user_registered",
      "user:user_confirmed",
      "user:user_email_changed",
      "user:user_anonymized"
    ]
  end

  def topics_for_aggregate(:enrollment) do
    [
      "enrollment:enrollment_created",
      "enrollment:enrollment_confirmed",
      "enrollment:enrollment_cancelled"
    ]
  end

  def topics_for_aggregate(:program) do
    [
      "program:program_created",
      "program:program_updated",
      "program:program_capacity_changed"
    ]
  end

  def topics_for_aggregate(_), do: []

  @doc """
  Returns all known topics across all aggregates.

  ## Examples

      iex> topics = EventTopics.all_topics()
      iex> "user:user_registered" in topics
      true
  """
  @spec all_topics() :: [String.t()]
  def all_topics do
    [:user, :enrollment, :program]
    |> Enum.flat_map(&topics_for_aggregate/1)
  end

  @doc """
  Parses a topic string into its components.

  Returns `{:ok, {aggregate_type, event_type}}` or `:error`.

  ## Examples

      iex> EventTopics.parse("user:user_registered")
      {:ok, {:user, :user_registered}}

      iex> EventTopics.parse("invalid")
      :error
  """
  @spec parse(String.t()) :: {:ok, {atom(), atom()}} | :error
  def parse(topic) when is_binary(topic) do
    case String.split(topic, ":", parts: 2) do
      [agg, event] ->
        {:ok, {String.to_existing_atom(agg), String.to_existing_atom(event)}}

      _ ->
        :error
    end
  rescue
    ArgumentError -> :error
  end
end
