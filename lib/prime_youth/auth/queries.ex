defmodule PrimeYouth.Auth.Queries do
  @moduledoc """
  Query module for read operations in the authentication context.
  Provides clean API for web layer to query user data without direct repository access.
  """

  alias PrimeYouth.Auth.Domain.User

  @doc """
  Gets a user by ID.

  Returns {:ok, user} if found, {:error, :not_found} otherwise.
  """
  def get_user_by_id(id, repo \\ default_repo()) do
    repo.find_by_id(id)
  end

  @doc """
  Gets a user by email.

  Returns {:ok, user} if found, {:error, :not_found} otherwise.
  """
  def get_user_by_email(email, repo \\ default_repo()) do
    repo.find_by_email(email)
  end

  @doc """
  Gets a user by session token.

  Returns {:ok, {user, token_inserted_at}} if found, {:error, :not_found} otherwise.
  """
  def get_user_by_session_token(token, repo \\ default_repo()) do
    repo.find_by_session_token(token)
  end

  @doc """
  Gets a user by magic link token.

  Returns {:ok, user} if found and token is valid, {:error, :invalid_token | :not_found} otherwise.
  """
  def get_user_by_magic_link_token(token, repo \\ default_repo()) do
    repo.verify_email_token(token, :magic_link)
  end

  @doc """
  Checks if a user is in sudo mode (recently authenticated).

  The user is in sudo mode when the last authentication was done no further
  than the specified number of minutes ago. Default is 20 minutes.

  ## Examples

      iex> sudo_mode?(user)
      true

      iex> sudo_mode?(user, -30)
      false
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
end
