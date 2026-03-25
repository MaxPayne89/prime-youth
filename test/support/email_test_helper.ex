defmodule KlassHero.EmailTestHelper do
  @moduledoc """
  Shared helpers for email testing.

  Provides utilities for draining Swoosh test mailbox messages
  that accumulate during fixture setup.
  """

  @doc """
  Drains all pending Swoosh email messages from the test process mailbox.

  Use after setup code (like `user_fixture/0`) that delivers emails as a
  side-effect, so those emails don't interfere with subsequent
  `assert_email_sent` calls.
  """
  def flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end
end
