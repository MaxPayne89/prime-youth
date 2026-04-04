defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.AttachmentMapper do
  @moduledoc """
  Maps between AttachmentSchema (Ecto) and Attachment (domain model).
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema
  alias KlassHero.Messaging.Domain.Models.Attachment

  @spec to_domain(AttachmentSchema.t()) :: Attachment.t()
  def to_domain(%AttachmentSchema{} = schema) do
    %Attachment{
      id: schema.id,
      message_id: schema.message_id,
      file_url: schema.file_url,
      original_filename: schema.original_filename,
      content_type: schema.content_type,
      file_size_bytes: schema.file_size_bytes,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @spec to_create_attrs(map()) :: map()
  def to_create_attrs(attrs) when is_map(attrs) do
    Map.take(attrs, [:message_id, :file_url, :original_filename, :content_type, :file_size_bytes])
  end
end
