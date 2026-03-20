defmodule KlassHero.Messaging.Application.UseCases.ReplyToEmailTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Application.UseCases.ReplyToEmail
  alias KlassHero.MessagingFixtures

  describe "execute/3" do
    test "sends a reply email and returns the swoosh email struct" do
      email = MessagingFixtures.inbound_email_fixture()

      assert {:ok, swoosh_email} = ReplyToEmail.execute(email.id, "Thank you for your message!")

      assert [{_name, address}] = swoosh_email.to
      assert address == email.from_address

      assert swoosh_email.subject == "Re: #{email.subject}"
      assert swoosh_email.text_body == "Thank you for your message!"
    end

    test "uses default from address" do
      email = MessagingFixtures.inbound_email_fixture()

      assert {:ok, swoosh_email} = ReplyToEmail.execute(email.id, "Hello!")

      assert swoosh_email.from == {"KlassHero", "noreply@mail.klasshero.com"}
    end

    test "accepts custom from address via opts" do
      email = MessagingFixtures.inbound_email_fixture()
      custom_from = {"Support", "support@example.com"}

      assert {:ok, swoosh_email} = ReplyToEmail.execute(email.id, "Hello!", from: custom_from)

      assert swoosh_email.from == custom_from
    end

    test "adds In-Reply-To and References headers when Message-ID header present" do
      message_id = "<original-message-id@mail.example.com>"

      email =
        MessagingFixtures.inbound_email_fixture(%{
          headers: [%{"name" => "Message-ID", "value" => message_id}]
        })

      assert {:ok, swoosh_email} = ReplyToEmail.execute(email.id, "Reply body")

      header_names = Enum.map(swoosh_email.headers, fn {name, _} -> name end)
      assert "In-Reply-To" in header_names
      assert "References" in header_names

      in_reply_to =
        Enum.find_value(swoosh_email.headers, fn {k, v} -> if k == "In-Reply-To", do: v end)

      references =
        Enum.find_value(swoosh_email.headers, fn {k, v} -> if k == "References", do: v end)

      assert in_reply_to == message_id
      assert references == message_id
    end

    test "does not add threading headers when no Message-ID present" do
      email = MessagingFixtures.inbound_email_fixture(%{headers: []})

      assert {:ok, swoosh_email} = ReplyToEmail.execute(email.id, "Reply body")

      threading_headers =
        Enum.filter(swoosh_email.headers, fn {name, _} ->
          name in ["In-Reply-To", "References"]
        end)

      assert threading_headers == []
    end

    test "handles lowercase message-id header" do
      message_id = "<lower-case-id@mail.example.com>"

      email =
        MessagingFixtures.inbound_email_fixture(%{
          headers: [%{"name" => "message-id", "value" => message_id}]
        })

      assert {:ok, swoosh_email} = ReplyToEmail.execute(email.id, "Reply body")

      in_reply_to =
        Enum.find_value(swoosh_email.headers, fn {k, v} -> if k == "In-Reply-To", do: v end)

      assert in_reply_to == message_id
    end

    test "returns {:error, :not_found} for unknown email id" do
      assert {:error, :not_found} = ReplyToEmail.execute(Ecto.UUID.generate(), "Reply body")
    end
  end
end
