defmodule KlassHeroWeb.E2E.MessagingHelpers do
  @moduledoc """
  Thin helper layer for messaging E2E tests.

  Centralizes DOM selectors and common multi-step browser interactions
  so tests stay readable without premature Page Object abstraction.
  """

  use Wallaby.DSL

  @password "hello world!"

  @doc """
  Starts a new Wallaby browser session with Ecto sandbox metadata attached.

  The metadata allows the browser's HTTP requests to share the test
  process's database transaction via the Phoenix.Ecto.SQL.Sandbox plug.
  """
  def new_session(metadata) do
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    session
  end

  @doc """
  Logs in through the UI as the given user.

  Navigates to the login page, toggles to the password form,
  fills in credentials, and submits. The user must have had
  `AccountsFixtures.set_password/1` called on them.
  """
  def log_in(session, %{email: email}) do
    session = visit(session, "/users/log-in")
    session = click(session, Query.button("Or use password"))

    # Wait for the password form to appear after the LiveView toggle
    assert_has(session, Query.css("#login_form_password"))

    session
    |> fill_in(Query.css("#login_form_password_email"), with: email)
    |> fill_in(Query.css("#user_password"), with: @password)
    |> click(Query.css("#login_form_password button[name='user[remember_me]']"))
  end

  @doc """
  Sends a message in the current conversation view.

  Fills the message textarea and clicks the send button.
  """
  def send_message(session, text) do
    session
    |> fill_in(Query.css("#message-input"), with: text)
    |> click(Query.css("[data-role=send-message-btn]"))
  end

  @doc """
  Asserts that a message with the given text is visible in the conversation.
  """
  def assert_message_visible(session, text) do
    assert_has(session, Query.css("[data-role=message]", text: text))
  end

  @doc """
  Asserts the unread count badge shows the expected number.
  """
  def assert_unread_count(session, count) do
    assert_has(session, Query.css("[data-role=unread-count]", text: to_string(count)))
  end

  @doc """
  Asserts no unread count badge is visible.
  """
  def refute_unread_count(session) do
    refute_has(session, Query.css("[data-role=unread-count]"))
  end

  @doc """
  Navigates to the conversation list for the given role.
  """
  def visit_conversations(session, :provider), do: visit(session, "/provider/messages")
  def visit_conversations(session, :parent), do: visit(session, "/messages")

  @doc """
  Opens a conversation by clicking its card with matching text.
  """
  def open_conversation(session, name) do
    click(session, Query.css("[data-role=conversation-card]", text: name))
  end
end
