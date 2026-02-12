defmodule KlassHero.Accounts.Adapters.Driven.Persistence.TokenCleanup do
  @moduledoc """
  Shared helper for updating a user and deleting all their tokens.

  Used by both the Accounts facade (password updates) and use cases
  (magic link login) that need to atomically update a user and
  invalidate all existing sessions.
  """

  import Ecto.Query, warn: false

  alias KlassHero.Accounts.UserToken
  alias KlassHero.Repo

  @doc """
  Updates a user via changeset and deletes all their tokens atomically.

  Returns `{:ok, {user, tokens}}` on success or `{:error, changeset}` on failure.
  The returned tokens are the ones that were deleted (for session invalidation).
  """
  def update_user_and_delete_all_tokens(changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:update_user, changeset)
    |> Ecto.Multi.run(:fetch_tokens, fn repo, %{update_user: user} ->
      tokens = repo.all_by(UserToken, user_id: user.id)
      {:ok, tokens}
    end)
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{fetch_tokens: tokens} ->
      from(t in UserToken, where: t.id in ^Enum.map(tokens, & &1.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_user: user, fetch_tokens: tokens}} -> {:ok, {user, tokens}}
      {:error, :update_user, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end
end
