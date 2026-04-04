defmodule KlassHero.Messaging.Domain.Models.AttachmentTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.Attachment

  describe "new/1" do
    test "creates attachment with valid attributes" do
      attrs = valid_attrs()

      assert {:ok, attachment} = Attachment.new(attrs)
      assert attachment.id == attrs.id
      assert attachment.message_id == attrs.message_id
      assert attachment.file_url == attrs.file_url
      assert attachment.original_filename == "photo.jpg"
      assert attachment.content_type == "image/jpeg"
      assert attachment.file_size_bytes == 2_400_000
    end

    test "accepts all allowed image content types" do
      for content_type <- ~w(image/jpeg image/png image/gif image/webp) do
        attrs = valid_attrs(%{content_type: content_type})
        assert {:ok, _} = Attachment.new(attrs), "expected #{content_type} to be valid"
      end
    end

    test "rejects unsupported content type" do
      attrs = valid_attrs(%{content_type: "application/pdf"})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "content_type"))
    end

    test "rejects file exceeding 10 MB" do
      attrs = valid_attrs(%{file_size_bytes: 10_485_761})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "file_size_bytes"))
    end

    test "accepts file at exactly 10 MB" do
      attrs = valid_attrs(%{file_size_bytes: 10_485_760})

      assert {:ok, _} = Attachment.new(attrs)
    end

    test "rejects zero file size" do
      attrs = valid_attrs(%{file_size_bytes: 0})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "file_size_bytes"))
    end

    test "rejects missing required fields" do
      assert {:error, ["Missing required fields"]} = Attachment.new(%{})
    end

    test "rejects empty file_url" do
      attrs = valid_attrs(%{file_url: ""})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "file_url"))
    end

    test "rejects empty original_filename" do
      attrs = valid_attrs(%{original_filename: ""})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "original_filename"))
    end
  end

  describe "allowed_content_types/0" do
    test "returns list of image MIME types" do
      types = Attachment.allowed_content_types()

      assert "image/jpeg" in types
      assert "image/png" in types
      assert "image/gif" in types
      assert "image/webp" in types
    end
  end

  describe "max_file_size_bytes/0" do
    test "returns 10 MB in bytes" do
      assert Attachment.max_file_size_bytes() == 10_485_760
    end
  end

  describe "max_per_message/0" do
    test "returns 5" do
      assert Attachment.max_per_message() == 5
    end
  end

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        id: Ecto.UUID.generate(),
        message_id: Ecto.UUID.generate(),
        file_url: "https://s3.example.com/messaging/attachments/#{Ecto.UUID.generate()}/photo.jpg",
        original_filename: "photo.jpg",
        content_type: "image/jpeg",
        file_size_bytes: 2_400_000
      },
      overrides
    )
  end
end
