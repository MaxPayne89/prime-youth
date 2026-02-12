defmodule KlassHero.Accounts.Application.UseCases.DeleteAccount do
  @moduledoc """
  Use case for account deletion with verification.

  Orchestrates:
  1. Verify sudo mode (recent authentication)
  2. Verify password matches
  3. Delegate to AnonymizeUser for actual deletion
  """

  alias KlassHero.Accounts.Application.UseCases.AnonymizeUser
  alias KlassHero.Accounts.User

  @sudo_timeout_minutes -20

  @doc """
  Deletes (anonymizes) a user account after password verification.

  Returns:
  - `{:ok, %User{}}` on success
  - `{:error, :sudo_required}` if not in sudo mode
  - `{:error, :invalid_password}` if password doesn't match
  """
  def execute(%User{} = user, password) when is_binary(password) do
    with :ok <- check_sudo_mode(user),
         :ok <- check_password(user, password) do
      AnonymizeUser.execute(user)
    end
  end

  # Trigger: user's last authentication is older than timeout
  # Why: sudo mode prevents account deletion without recent auth
  # Outcome: returns :ok or {:error, :sudo_required}
  defp check_sudo_mode(%User{authenticated_at: ts}) when is_struct(ts, DateTime) do
    cutoff = DateTime.utc_now() |> DateTime.add(@sudo_timeout_minutes, :minute)

    if DateTime.after?(ts, cutoff) do
      :ok
    else
      {:error, :sudo_required}
    end
  end

  defp check_sudo_mode(_user), do: {:error, :sudo_required}

  defp check_password(%User{} = user, password) do
    if User.valid_password?(user, password) do
      :ok
    else
      {:error, :invalid_password}
    end
  end
end
