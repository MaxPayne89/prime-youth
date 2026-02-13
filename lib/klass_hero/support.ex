defmodule KlassHero.Support do
  @moduledoc """
  Public API for the Support bounded context.

  Manages contact forms and support requests.
  """

  use Boundary,
    top_level?: true,
    deps: [KlassHero.Shared],
    exports: [
      Application.UseCases.SubmitContactForm,
      Domain.Models.ContactForm
    ]
end
