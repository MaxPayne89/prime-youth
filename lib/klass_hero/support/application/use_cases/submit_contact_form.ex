defmodule KlassHero.Support.Application.UseCases.SubmitContactForm do
  @moduledoc """
  Use case for submitting contact form requests.

  This use case implements the business logic for handling contact form
  submissions. It validates form data using the ContactForm changeset,
  creates a ContactRequest domain entity, and submits it via the
  configured repository adapter.

  ## Workflow

  1. Validate form params using ContactForm changeset
  2. Generate unique ID and timestamp
  3. Create ContactRequest domain entity
  4. Submit via configured repository
  5. Return result to caller

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Contains business logic for contact form submission
  - Orchestrates validation and repository operations
  - Maintains independence from infrastructure details
  - Returns domain entities or validation errors

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :klass_hero, :support,
        repository: KlassHero.Support.Adapters.Driven.Persistence.Repositories.ContactRequestRepository

  ## Example Usage

      # Valid submission
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "general",
        "message" => "I have a question about your programs."
      }
      {:ok, contact_request} = SubmitContactForm.execute(params)

      # Invalid submission
      params = %{"name" => "", "email" => "invalid", ...}
      {:error, changeset} = SubmitContactForm.execute(params)

      # Repository error
      {:error, :repository_unavailable} = SubmitContactForm.execute(valid_params)
  """

  alias KlassHero.Shared.DomainEventBus
  alias KlassHero.Support.Domain.Events.SupportEvents
  alias KlassHero.Support.Domain.Models.ContactForm
  alias KlassHero.Support.Domain.Models.ContactRequest

  @context KlassHero.Support

  @doc """
  Executes the contact form submission use case.

  The function performs the following steps:
  1. Validates form parameters using ContactForm changeset
  2. If validation succeeds, creates a ContactRequest entity
  3. Submits the contact request via the configured repository
  4. Returns the result to the caller

  ## Parameters

  - `params` - Map of form parameters with string keys:
    - `"name"` - Person's name (required, 2-100 chars)
    - `"email"` - Email address (required, must contain @)
    - `"subject"` - Subject category (required, enum value)
    - `"message"` - Message text (required, 10-1000 chars)

  ## Returns

  - `{:ok, ContactRequest.t()}` - Successfully submitted contact request
  - `{:error, Ecto.Changeset.t()}` - Validation failed with changeset errors
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error

  ## Examples

      # Successful submission
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "general",
        "message" => "I have a question about your programs."
      }
      {:ok, contact} = execute(params)
      assert contact.id =~ ~r/^contact_/
      assert contact.name == "John Doe"

      # Validation error - invalid email
      params = %{...valid..., "email" => "invalid"}
      {:error, changeset} = execute(params)
      assert "must contain @" in errors_on(changeset).email

      # Validation error - message too short
      params = %{...valid..., "message" => "Short"}
      {:error, changeset} = execute(params)
      assert "should be at least 10 character(s)" in errors_on(changeset).message
  """
  @spec execute(map()) ::
          {:ok, ContactRequest.t()}
          | {:error, Ecto.Changeset.t() | :repository_unavailable | :repository_error}
  def execute(params) do
    changeset = ContactForm.changeset(%ContactForm{}, params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, validated_form} ->
        contact_request = build_contact_request(validated_form)

        with {:ok, submitted_request} <- repository_module().submit(contact_request) do
          DomainEventBus.dispatch(
            @context,
            SupportEvents.contact_request_submitted(submitted_request)
          )

          {:ok, submitted_request}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp build_contact_request(validated_form) do
    %ContactRequest{
      id: generate_id(),
      name: validated_form.name,
      email: validated_form.email,
      subject: validated_form.subject,
      message: validated_form.message,
      submitted_at: DateTime.utc_now()
    }
  end

  defp generate_id do
    "contact_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp repository_module do
    Application.get_env(:klass_hero, :support)[:repository]
  end
end
