defmodule KlassHero.Provider.Application.Queries.StaffMemberQueries do
  @moduledoc """
  Query module for staff member reads.

  Centralises all read operations that depend on the staff member repository,
  keeping the facade free of direct repository references.
  """

  alias KlassHero.Provider.Domain.Models.StaffMember

  @staff_repository Application.compile_env!(:klass_hero, [
                      :provider,
                      :for_querying_staff_members
                    ])

  @doc """
  Retrieves a single staff member by ID.
  """
  @spec get(String.t()) :: {:ok, StaffMember.t()} | {:error, :not_found}
  def get(staff_id) when is_binary(staff_id) do
    @staff_repository.get(staff_id)
  end

  @doc """
  Lists all staff members for a provider, ordered by insertion date.
  """
  @spec list_by_provider(String.t()) :: {:ok, [StaffMember.t()]}
  def list_by_provider(provider_id) when is_binary(provider_id) do
    @staff_repository.list_by_provider(provider_id)
  end

  @doc """
  Lists active staff members for a provider.
  """
  @spec list_active_by_provider(String.t()) :: {:ok, [StaffMember.t()]}
  def list_active_by_provider(provider_id) when is_binary(provider_id) do
    @staff_repository.list_active_by_provider(provider_id)
  end

  @doc """
  Returns the active staff member record linked to the given user ID.
  Used by Scope to resolve :staff_provider role.
  """
  @spec get_active_by_user(String.t()) :: {:ok, StaffMember.t()} | {:error, :not_found}
  def get_active_by_user(user_id) when is_binary(user_id) do
    @staff_repository.get_active_by_user(user_id)
  end

  @doc """
  Returns the staff member matching the given invitation token hash,
  only if invitation_status is :sent. Used by the invitation registration flow.
  """
  @spec get_by_token_hash(binary()) :: {:ok, StaffMember.t()} | {:error, :not_found}
  def get_by_token_hash(token_hash) when is_binary(token_hash) do
    @staff_repository.get_by_token_hash(token_hash)
  end
end
