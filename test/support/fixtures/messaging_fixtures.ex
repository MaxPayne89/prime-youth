defmodule KlassHero.MessagingFixtures do
  @moduledoc """
  Test fixtures for the Messaging bounded context.
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository

  def unique_resend_id, do: "resend_#{System.unique_integer([:positive])}"

  def valid_inbound_email_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      resend_id: unique_resend_id(),
      from_address: "sender#{System.unique_integer([:positive])}@example.com",
      to_addresses: ["hello@klasshero.com"],
      subject: "Test Email #{System.unique_integer([:positive])}",
      body_html: "<p>Hello</p>",
      body_text: "Hello",
      headers: [],
      received_at: DateTime.utc_now()
    })
  end

  def inbound_email_fixture(attrs \\ %{}) do
    {:ok, email} =
      attrs
      |> valid_inbound_email_attrs()
      |> InboundEmailRepository.create()

    email
  end
end
