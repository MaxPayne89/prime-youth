defmodule KlassHero.Messaging.Application.Commands.StartProgramConversation do
  @moduledoc """
  Use case for a parent initiating a direct conversation about a specific program.

  Resolves the provider owner's user ID via the `ForResolvingUsers` port and
  delegates to `CreateDirectConversation` with the program context so assigned
  staff are auto-added as participants.
  """

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging.Application.Commands.CreateDirectConversation
  alias KlassHero.Messaging.Domain.Models.Conversation

  @user_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_users])

  @spec execute(Scope.t(), String.t(), String.t()) ::
          {:ok, Conversation.t()} | {:error, :not_found | :not_entitled | term()}
  def execute(%Scope{} = scope, provider_id, program_id) do
    with {:ok, owner_user_id} <- @user_resolver.get_user_id_for_provider(provider_id) do
      CreateDirectConversation.execute(scope, provider_id, owner_user_id, program_id: program_id)
    end
  end
end
