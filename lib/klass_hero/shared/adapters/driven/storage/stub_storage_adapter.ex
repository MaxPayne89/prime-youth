defmodule KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter do
  @moduledoc """
  In-memory stub adapter for testing file storage operations.

  Stores files in an Agent for test assertions.
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForStoringFiles

  use Agent

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{} end, name: name)
  end

  @impl true
  def upload(bucket_type, path, binary, opts) do
    agent = Keyword.get(opts, :agent, __MODULE__)
    key = make_key(bucket_type, path)

    Agent.update(agent, fn state ->
      Map.put(state, key, binary)
    end)

    case bucket_type do
      :public -> {:ok, "stub://public/#{path}"}
      :private -> {:ok, path}
    end
  end

  @impl true
  def signed_url(_bucket_type, key, expires_in, opts) do
    _agent = Keyword.get(opts, :agent, __MODULE__)
    {:ok, "stub://signed/#{key}?expires=#{expires_in}"}
  end

  @impl true
  # Trigger: check if Agent process is running
  # Why: some tests don't start the StubStorageAdapter Agent
  # Outcome: returns actual state if running, defaults to true if not started
  def file_exists?(bucket_type, path, opts) do
    agent = Keyword.get(opts, :agent, __MODULE__)
    key = make_key(bucket_type, path)

    if Process.whereis(agent) do
      exists? = Agent.get(agent, fn state -> Map.has_key?(state, key) end)
      {:ok, exists?}
    else
      {:ok, true}
    end
  end

  @impl true
  def delete(bucket_type, path, opts) do
    agent = Keyword.get(opts, :agent, __MODULE__)
    key = make_key(bucket_type, path)

    Agent.update(agent, fn state ->
      Map.delete(state, key)
    end)

    :ok
  end

  @doc """
  Test helper to retrieve uploaded file content.
  """
  def get_uploaded(bucket_type, path, opts \\ []) do
    agent = Keyword.get(opts, :agent, __MODULE__)
    key = make_key(bucket_type, path)

    case Agent.get(agent, fn state -> Map.get(state, key) end) do
      nil -> {:error, :file_not_found}
      binary -> {:ok, binary}
    end
  end

  @doc """
  Test helper to clear all stored files.
  """
  def clear(opts \\ []) do
    agent = Keyword.get(opts, :agent, __MODULE__)
    Agent.update(agent, fn _state -> %{} end)
  end

  defp make_key(bucket_type, path), do: "#{bucket_type}:#{path}"
end
