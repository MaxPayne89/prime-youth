defmodule Mix.Tasks.Test.Db.Setup do
  @moduledoc """
  Sets up the test database in the PostgreSQL container.

  Creates the test database if it doesn't exist, ensuring the test environment
  can connect properly.
  """
  use Mix.Task

  @shortdoc "Creates the test database in PostgreSQL container"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Setting up test database...")

    with :ok <- ensure_test_db_exists() do
      Mix.shell().info([:green, "✓ Test database ready!"])
    else
      {:error, reason} ->
        Mix.shell().error([:red, "✗ Failed to setup test database: #{reason}"])
        System.halt(1)
    end
  end

  @container_name "prime_youth_postgres"
  @database_name "prime_youth_test"

  defp ensure_test_db_exists do
    create_db_command = build_create_db_command()

    case System.cmd("docker", create_db_command, stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("Test database created successfully")
        :ok

      {output, _} ->
        handle_create_db_error(output)
    end
  end

  defp build_create_db_command do
    [
      "exec",
      @container_name,
      "psql",
      "-U",
      "postgres",
      "-c",
      "CREATE DATABASE #{@database_name};"
    ]
  end

  defp handle_create_db_error(output) do
    if String.contains?(output, "already exists") do
      Mix.shell().info("Test database already exists")
      :ok
    else
      {:error, "Failed to create test database: #{output}"}
    end
  end
end