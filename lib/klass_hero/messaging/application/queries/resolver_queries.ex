defmodule KlassHero.Messaging.Application.Queries.ResolverQueries do
  @moduledoc """
  Queries for resolving user and staff information via ACL adapters.
  """

  @user_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_users])
  @staff_resolver Application.compile_env!(:klass_hero, [
                    :messaging,
                    :for_resolving_program_staff
                  ])

  @doc """
  Returns the display name for a user.

  ## Parameters
  - user_id: The user ID to resolve

  ## Returns
  - `{:ok, name}` - The user's display name
  - `{:error, :not_found}` - User not found
  """
  @spec get_display_name(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_display_name(user_id) do
    @user_resolver.get_display_name(user_id)
  end

  @doc """
  Returns the user IDs of active staff assigned to a program.

  ## Parameters
  - program_id: The program to look up staff for

  ## Returns
  - List of user ID strings
  """
  @spec get_active_staff_user_ids(String.t()) :: [String.t()]
  def get_active_staff_user_ids(program_id) do
    @staff_resolver.get_active_staff_user_ids(program_id)
  end
end
