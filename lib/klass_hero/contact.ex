defmodule KlassHero.Contact do
  @moduledoc """
  Centralized access to contact information from application config.
  """

  def email, do: get(:email)
  def phone, do: get(:phone)
  def address, do: get(:address)

  defp get(key) do
    :klass_hero
    |> Application.get_env(:contact, [])
    |> Keyword.get(key)
  end
end
