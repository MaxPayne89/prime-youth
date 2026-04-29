defmodule KlassHero.Enrollment.Application.Commands.EnqueueInviteEmails do
  @moduledoc """
  Use case that generates invite tokens for pending bulk enrollment invites
  and returns data needed to enqueue email delivery.

  Orchestrates: query pending invites -> resolve program names -> generate tokens -> bulk assign.

  Returns `{invite_id, program_name}` pairs so the calling adapter can create
  infrastructure-specific jobs (e.g. Oban workers).
  """

  alias KlassHero.Enrollment.Domain.Models.BulkEnrollmentInvite

  require Logger

  @invite_reader Application.compile_env!(:klass_hero, [
                   :enrollment,
                   :for_querying_bulk_enrollment_invites
                 ])
  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])
  @program_catalog_acl Application.compile_env!(:klass_hero, [
                         :enrollment,
                         :for_resolving_program_catalog
                       ])

  @spec execute([binary()], binary()) :: {:ok, [{binary(), String.t()}]}
  def execute(program_ids, provider_id) when is_list(program_ids) and is_binary(provider_id) do
    pending_invites = @invite_reader.list_pending_without_token(program_ids)

    if pending_invites == [] do
      Logger.info("[Enrollment.EnqueueInviteEmails] No pending invites to process")
      {:ok, []}
    else
      process_invites(pending_invites, provider_id)
    end
  end

  defp process_invites(invites, provider_id) do
    programs_by_id = build_programs_by_id(provider_id)

    id_token_pairs =
      Enum.map(invites, fn invite ->
        {invite.id, BulkEnrollmentInvite.generate_token()}
      end)

    {:ok, _count} = @invite_repository.bulk_assign_tokens(id_token_pairs)

    pairs =
      Enum.map(invites, fn invite ->
        program_name = Map.get(programs_by_id, invite.program_id, "Program")
        {invite.id, program_name}
      end)

    Logger.info("[Enrollment.EnqueueInviteEmails] Prepared invite emails",
      count: length(pairs)
    )

    {:ok, pairs}
  end

  defp build_programs_by_id(provider_id) do
    @program_catalog_acl.list_program_titles_for_provider(provider_id)
    |> Map.new(fn {title, id} -> {id, title} end)
  end
end
