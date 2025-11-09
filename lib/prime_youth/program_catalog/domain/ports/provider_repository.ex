defmodule PrimeYouth.ProgramCatalog.Domain.Ports.ProviderRepository do
  @moduledoc """
  Repository port for Provider persistence operations.

  This behavior defines the contract for provider data access.
  Implementations must be provided by the infrastructure layer (e.g., Ecto adapter).

  ## Implementation

  Configure the implementation in `config/config.exs`:

      config :prime_youth, :provider_repository,
        module: PrimeYouth.ProgramCatalog.Adapters.Ecto.ProviderRepository
  """

  @doc """
  Retrieves a provider by their associated user ID.

  ## Parameters

    * `user_id` - The binary ID of the associated user account

  ## Returns

    * `{:ok, provider}` - Provider found
    * `{:error, :not_found}` - No provider associated with this user
  """
  @callback get_by_user_id(user_id :: binary()) ::
              {:ok, struct()} | {:error, :not_found}
end
