defmodule KlassHero.Enrollment.InviteClaimSagaTest do
  @moduledoc """
  Integration test for the full invite claim saga.

  Verifies the end-to-end flow: token claim -> user creation ->
  invite_claimed event -> registered status transition ->
  integration event -> family creation -> enrollment creation.

  Since integration events propagate asynchronously via PubSub
  (through EventSubscriber GenServers started in the application tree),
  this test:

  1. Swaps the integration event publisher to the real PubSub publisher
     so that PromoteIntegrationEvents handlers actually broadcast events
  2. Grants Ecto Sandbox access to the EventSubscriber processes so they
     can access the database within the test's transaction
  3. Polls for the expected terminal state ("enrolled")
  """
  use KlassHero.DataCase, async: false

  import KlassHero.Factory

  alias Ecto.Adapters.SQL.Sandbox
  alias KlassHero.Enrollment

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Family
  alias KlassHero.Repo

  # EventSubscriber process names that participate in the saga.
  # These GenServers receive PubSub integration events and access the DB.
  @saga_subscribers [
    # Handles integration:enrollment:invite_claimed -> creates parent + child
    KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler,
    # Handles integration:family:invite_family_ready -> creates enrollment
    KlassHero.Enrollment.Adapters.Driven.Events.InviteFamilyReadyHandler,
    # Handles integration:accounts:user_registered -> creates parent profile (may race)
    KlassHero.Family.Adapters.Driven.Events.FamilyEventHandler,
    # Handles integration:accounts:user_registered -> creates provider profile stub
    KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler
  ]

  defp create_claimable_invite(_context) do
    import Ecto.Query

    provider = insert(:provider_profile_schema)

    program =
      insert(:program_schema,
        provider_id: provider.id
      )

    token = "saga-test-#{System.unique_integer([:positive])}"
    email = "saga-test-#{System.unique_integer([:positive])}@example.com"

    {:ok, 1} =
      BulkEnrollmentInviteRepository.create_batch([
        %{
          program_id: program.id,
          provider_id: provider.id,
          child_first_name: "Emma",
          child_last_name: "Schmidt",
          child_date_of_birth: ~D[2016-03-15],
          guardian_email: email,
          guardian_first_name: "Anna",
          guardian_last_name: "Schmidt"
        }
      ])

    invite =
      BulkEnrollmentInviteSchema
      |> where([i], i.guardian_email == ^email and i.program_id == ^program.id)
      |> Repo.one!()

    # Transition invite to "invite_sent" with a token so it can be claimed
    invite
    |> Ecto.Changeset.change(%{invite_token: token, status: "invite_sent"})
    |> Repo.update!()

    updated_invite =
      BulkEnrollmentInviteSchema
      |> where([i], i.id == ^invite.id)
      |> Repo.one!()

    %{
      invite: updated_invite,
      token: token,
      program: program,
      provider: provider,
      email: email
    }
  end

  describe "full invite claim saga" do
    setup context do
      # Trigger: test config uses TestIntegrationEventPublisher (process dictionary storage)
      # Why: PromoteIntegrationEvents handlers must actually broadcast to PubSub so the
      #      EventSubscriber GenServers receive the events and drive the saga forward
      # Outcome: swap to real PubSub publisher for this test, restore in on_exit
      original_config = Application.get_env(:klass_hero, :integration_event_publisher)

      Application.put_env(:klass_hero, :integration_event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher,
        pubsub: KlassHero.PubSub
      )

      on_exit(fn ->
        Application.put_env(:klass_hero, :integration_event_publisher, original_config)
      end)

      # Trigger: EventSubscriber GenServers run in separate processes outside the test
      # Why: they need DB access to handle integration events (create parent, child, enrollment)
      # Outcome: allow each subscriber to share the test process's sandboxed connection
      Enum.each(@saga_subscribers, fn subscriber_name ->
        case Process.whereis(subscriber_name) do
          nil -> :ok
          pid -> Sandbox.allow(KlassHero.Repo, self(), pid)
        end
      end)

      create_claimable_invite(context)
    end

    test "claim_invite triggers the full saga: user -> registered -> family -> enrolled", %{
      token: token,
      invite: invite
    } do
      # Step 1: Claim the invite — this triggers the synchronous domain event bus
      assert {:ok, :new_user, user, _invite} = Enrollment.claim_invite(token)

      # Step 2: Verify synchronous effects (domain event handlers on Enrollment bus)
      # MarkInviteRegistered runs synchronously via DomainEventBus.dispatch
      # PromoteIntegrationEvents also runs synchronously, broadcasting to PubSub
      updated = Repo.get!(BulkEnrollmentInviteSchema, invite.id)
      assert updated.status == "registered"
      assert updated.registered_at != nil

      # Step 3: Wait for async effects (integration events via PubSub)
      # Family InviteClaimedHandler creates parent + child, publishes :invite_family_ready
      # Family PromoteIntegrationEvents broadcasts to PubSub
      # Enrollment InviteFamilyReadyHandler creates enrollment, transitions invite to enrolled
      assert_eventually(
        fn ->
          final = Repo.get!(BulkEnrollmentInviteSchema, invite.id)
          final.status == "enrolled"
        end,
        timeout_ms: 5000,
        interval_ms: 100
      )

      # Verify terminal invite state
      final = Repo.get!(BulkEnrollmentInviteSchema, invite.id)
      assert final.status == "enrolled"
      assert final.enrolled_at != nil
      assert final.enrollment_id != nil

      # Verify family was created
      assert {:ok, parent} = Family.get_parent_by_identity(user.id)
      children = Family.get_children(parent.id)
      assert [_ | _] = children
      assert Enum.any?(children, &(&1.first_name == "Emma"))
    end
  end

  # Polling helper for async assertions
  defp assert_eventually(fun, opts) do
    timeout = Keyword.get(opts, :timeout_ms, 5000)
    interval = Keyword.get(opts, :interval_ms, 100)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_assert_eventually(fun, interval, deadline)
  end

  defp do_assert_eventually(fun, interval, deadline) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) > deadline do
        flunk("Condition not met within timeout")
      else
        Process.sleep(interval)
        do_assert_eventually(fun, interval, deadline)
      end
    end
  end
end
