defmodule KlassHero.Enrollment.Application.ChangesetErrors do
  @moduledoc """
  Converts an `Ecto.Changeset`'s errors into the flat
  `[{field :: atom, message :: String.t()}]` list that enrollment commands
  surface to the LiveView layer. Expands `%{count}`-style placeholders so
  messages like `"should be at most %{count} character(s)"` don't leak to
  end users.
  """

  @doc """
  Flatten a changeset's errors into `[{field, expanded_message}]` pairs.
  """
  @spec field_list(Ecto.Changeset.t()) :: [{atom(), String.t()}]
  def field_list(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&expand/1)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn msg -> {field, msg} end)
    end)
  end

  defp expand({msg, opts}) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
