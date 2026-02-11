defmodule KlassHero.Accounts.Application.UseCases.DeleteAccount do
  @moduledoc """
  Use case for account deletion with verification.

  Orchestrates:
  1. Verify sudo mode (recent authentication)
  2. Verify password matches
  3. Delegate to AnonymizeUser for actual deletion
  """

  alias KlassHero.Accounts
  alias KlassHero.Accounts.Application.UseCases.AnonymizeUser
  alias KlassHero.Accounts.User

  @doc """
  Deletes (anonymizes) a user account after password verification.

  Returns:
  - `{:ok, %User{}}` on success
  - `{:error, :sudo_required}` if not in sudo mode
  - `{:error, :invalid_password}` if password doesn't match
  """
  def execute(%User{} = user, password) when is_binary(password) do
    with true <- Accounts.sudo_mode?(user),
         %User{} <- Accounts.get_user_by_email_and_password(user.email, password) do
      AnonymizeUser.execute(user)
    else
      false -> {:error, :sudo_required}
      nil -> {:error, :invalid_password}
    end
  end
end
