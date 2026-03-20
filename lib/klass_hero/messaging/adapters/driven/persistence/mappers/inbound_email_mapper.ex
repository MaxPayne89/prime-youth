defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.InboundEmailMapper do
  @moduledoc """
  Maps between InboundEmailSchema (Ecto) and InboundEmail (domain model).
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema
  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @doc """
  Converts an InboundEmailSchema to a domain InboundEmail.
  """
  @spec to_domain(InboundEmailSchema.t()) :: InboundEmail.t()
  def to_domain(%InboundEmailSchema{} = schema) do
    %InboundEmail{
      id: schema.id,
      resend_id: schema.resend_id,
      from_address: schema.from_address,
      from_name: schema.from_name,
      to_addresses: schema.to_addresses,
      cc_addresses: schema.cc_addresses,
      subject: schema.subject,
      body_html: schema.body_html,
      body_text: schema.body_text,
      headers: schema.headers,
      status: String.to_existing_atom(schema.status),
      read_by_id: schema.read_by_id,
      read_at: schema.read_at,
      received_at: schema.received_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts creation attributes to schema-compatible format.
  """
  @spec to_create_attrs(map()) :: map()
  def to_create_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.take([
      :resend_id,
      :from_address,
      :from_name,
      :to_addresses,
      :cc_addresses,
      :subject,
      :body_html,
      :body_text,
      :headers,
      :received_at
    ])
    |> Map.put_new(:status, "unread")
  end
end
