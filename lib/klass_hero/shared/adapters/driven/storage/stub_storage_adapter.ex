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
  # Trigger: Agent may not be started in LiveView integration tests
  # Why: LiveView tests can't pass custom storage_opts; matches signed_url/file_exists? pattern
  # Outcome: stores file if agent alive, returns stub URL regardless
  def upload(bucket_type, path, binary, opts) do
    agent = Keyword.get(opts, :agent, __MODULE__)
    key = make_key(bucket_type, path)

    if agent_alive?(agent) do
      Agent.update(agent, fn state ->
        Map.put(state, key, binary)
      end)
    end

    case bucket_type do
      :public -> {:ok, "stub://public/#{path}"}
      :private -> {:ok, path}
    end
  end

  @impl true
  # Trigger: check if Agent process is running before verifying key existence
  # Why: some tests don't start the StubStorageAdapter Agent
  # Outcome: returns signed URL if file exists or Agent not started, :file_not_found otherwise
  def signed_url(bucket_type, key, expires_in, opts) do
    agent = Keyword.get(opts, :agent, __MODULE__)

    if agent_alive?(agent) do
      store_key = make_key(bucket_type, key)
      exists? = Agent.get(agent, fn state -> Map.has_key?(state, store_key) end)

      if exists? do
        {:ok, "stub://signed/#{key}?expires=#{expires_in}"}
      else
        {:error, :file_not_found}
      end
    else
      {:ok, "stub://signed/#{key}?expires=#{expires_in}"}
    end
  end

  @impl true
  # Trigger: check if Agent process is running
  # Why: some tests don't start the StubStorageAdapter Agent
  # Outcome: returns actual state if running, defaults to true if not started
  def file_exists?(bucket_type, path, opts) do
    agent = Keyword.get(opts, :agent, __MODULE__)
    key = make_key(bucket_type, path)

    if agent_alive?(agent) do
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

  # Trigger: agent can be a PID (from start_link) or an atom (registered name)
  # Why: Process.whereis/1 only accepts atoms; PIDs are already process references
  # Outcome: returns true if the agent process is alive, regardless of reference type
  defp agent_alive?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp agent_alive?(name) when is_atom(name), do: Process.whereis(name) != nil

  defp make_key(bucket_type, path), do: "#{bucket_type}:#{path}"
end
