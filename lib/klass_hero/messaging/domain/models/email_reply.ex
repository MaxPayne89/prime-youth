defmodule KlassHero.Messaging.Domain.Models.EmailReply do
  @moduledoc """
  Pure domain entity for an email reply sent from the admin dashboard.

  Supports status transitions: sending -> sent | failed.
  """

  @enforce_keys [:id, :inbound_email_id, :body, :sent_by_id]

  defstruct [
    :id,
    :inbound_email_id,
    :body,
    :sent_by_id,
    :resend_message_id,
    :sent_at,
    :inserted_at,
    :updated_at,
    status: :sending
  ]

  @type status :: :sending | :sent | :failed

  @type t :: %__MODULE__{
          id: String.t(),
          inbound_email_id: String.t(),
          body: String.t(),
          sent_by_id: String.t(),
          status: status(),
          resend_message_id: String.t() | nil,
          sent_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @required_fields [:id, :inbound_email_id, :body, :sent_by_id]

  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    attrs = Map.put_new(attrs, :status, :sending)

    case build_struct(attrs) do
      {:ok, reply} ->
        case validate(reply) do
          [] -> {:ok, reply}
          errors -> {:error, errors}
        end

      {:error, errors} when is_list(errors) ->
        {:error, errors}
    end
  end

  @spec mark_sent(t(), String.t()) :: {:ok, t()}
  def mark_sent(%__MODULE__{status: :sent} = reply, _resend_message_id), do: {:ok, reply}

  def mark_sent(%__MODULE__{status: :sending} = reply, resend_message_id) do
    {:ok, %{reply | status: :sent, resend_message_id: resend_message_id, sent_at: DateTime.utc_now()}}
  end

  @spec mark_failed(t()) :: {:ok, t()}
  def mark_failed(%__MODULE__{status: :sending} = reply) do
    {:ok, %{reply | status: :failed}}
  end

  defp build_struct(attrs) do
    missing =
      Enum.filter(@required_fields, fn field ->
        is_nil(Map.get(attrs, field))
      end)

    case missing do
      [] ->
        {:ok, struct!(__MODULE__, attrs)}

      fields ->
        errors = Enum.map(fields, &"#{&1} is required")
        {:error, errors}
    end
  end

  defp validate(reply) do
    []
    |> validate_body_not_blank(reply)
  end

  defp validate_body_not_blank(errors, reply) do
    if is_binary(reply.body) and String.trim(reply.body) == "" do
      errors ++ ["body must not be blank"]
    else
      errors
    end
  end
end
