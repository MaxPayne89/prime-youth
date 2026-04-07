defmodule KlassHero.Provider.Domain.Ports.ForCallingStripeIdentity do
  @moduledoc """
  Port for creating and retrieving Stripe Identity Verification Sessions.

  Implemented by StripeIdentityAdapter in production and StubStripeIdentityAdapter in tests.
  """

  @typedoc "Result of creating a Stripe Identity verification session."
  @type session_result :: %{
          session_id: String.t(),
          url: String.t()
        }

  @typedoc "Result of retrieving a Stripe Identity session's current status."
  @type session_status_result :: %{
          session_id: String.t(),
          status: :verified | :requires_input | :canceled | :processing | :created,
          verified_outputs: map() | nil
        }

  @doc """
  Creates a new Stripe Identity Verification Session.

  Options:
  - `:return_url` (required) — URL Stripe redirects the provider to after completion

  Returns `{:ok, session_result()}` or `{:error, term()}`.
  """
  @callback create_verification_session(opts :: keyword()) ::
              {:ok, session_result()} | {:error, term()}

  @doc """
  Retrieves a Stripe Identity Verification Session by its ID.

  Returns `{:ok, session_status_result()}` or `{:error, :not_found | term()}`.
  """
  @callback get_verification_session(session_id :: String.t()) ::
              {:ok, session_status_result()} | {:error, :not_found | term()}
end
