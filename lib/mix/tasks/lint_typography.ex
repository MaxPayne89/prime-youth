defmodule Mix.Tasks.LintTypography do
  @shortdoc "Check for raw font-display classes in templates (use Theme.typography instead)"
  @moduledoc """
  Checks for raw `font-display` class usage in LiveView and component files.

  All display typography should go through `Theme.typography/1` for consistency.
  Lines containing `typography-lint-ignore` are excluded from checks.

  ## Usage

      mix lint_typography
  """
  use Boundary, classify_to: KlassHero.Application
  use Mix.Task

  @search_dir "lib/klass_hero_web/"
  @excluded_files ["theme.ex"]
  @suppression_marker "typography-lint-ignore"

  @impl true
  def run(_args) do
    violations =
      Path.wildcard(Path.join(@search_dir, "**/*.ex"))
      |> Enum.reject(fn path -> Enum.any?(@excluded_files, &String.ends_with?(path, &1)) end)
      |> Enum.flat_map(&find_violations/1)

    if violations == [] do
      Mix.shell().info("Typography lint passed — no raw font-display usage found.")
    else
      Mix.shell().error("Raw font-display classes found. Use Theme.typography() instead:\n")

      Enum.each(violations, fn {file, line_num, line} ->
        Mix.shell().error("  #{file}:#{line_num}: #{String.trim(line)}")
      end)

      Mix.raise("Typography lint failed — #{length(violations)} violation(s) found")
    end
  end

  defp find_violations(file) do
    lines =
      file
      |> File.read!()
      |> String.split("\n")

    lines
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, line_num} ->
      has_violation =
        String.contains?(line, "font-display") and not String.contains?(line, @suppression_marker)

      # Also check the preceding line for a suppression comment
      prev_line = Enum.at(lines, line_num - 2, "")
      has_violation and not String.contains?(prev_line, @suppression_marker)
    end)
    |> Enum.map(fn {line, num} -> {file, num, line} end)
  end
end
