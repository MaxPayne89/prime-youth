defmodule PrimeYouthWeb.ProgramLive.Form do
  @moduledoc """
  LiveView for creating and editing provider programs.

  Supports:
  - Creating new programs (draft status by default)
  - Editing existing programs (draft and rejected only)
  - Real-time validation
  - Multi-step form with basic info, scheduling, and location
  - Submit for approval workflow integration

  Authorization:
  - Requires authenticated user with provider account
  - Providers can only edit their own programs
  - Approved programs cannot be edited
  """

  use PrimeYouthWeb, :live_view

  import Ecto.Query

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.{Program, Provider}
  alias PrimeYouth.ProgramCatalog.UseCases.{CreateProgram, UpdateProgram}
  alias PrimeYouth.Repo

  @impl true
  def mount(params, _session, socket) do
    # Get current user from scope
    current_user = socket.assigns.current_scope.user

    # Get provider for current user
    provider = get_provider_by_user_id(current_user.id)

    case provider do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Please complete your provider profile first.")
          |> redirect(to: ~p"/dashboard")

        {:ok, socket}

      provider ->
        socket = initialize_form(socket, params, provider)
        socket = add_form_data(socket)
        {:ok, socket}
    end
  end

  # Private mount helper functions

  defp initialize_form(socket, params, provider) do
    program_id = Map.get(params, "id")

    if program_id do
      load_program_for_edit(socket, program_id, provider)
    else
      setup_new_program(socket, provider)
    end
  end

  defp load_program_for_edit(socket, program_id, provider) do
    program = get_program_for_editing(program_id, provider.id)

    case program do
      nil ->
        socket
        |> put_flash(:error, "Program not found.")
        |> redirect(to: ~p"/provider/dashboard")

      %Program{status: status} when status in ["draft", "rejected"] ->
        socket
        |> assign(:page_title, "Edit Program")
        |> assign(:action, :edit)
        |> assign(:provider, provider)
        |> assign(:program, program)
        |> assign(:form, to_form(Program.changeset(program, %{})))

      _approved_program ->
        socket
        |> put_flash(:error, "Cannot edit approved programs.")
        |> redirect(to: ~p"/provider/dashboard")
    end
  end

  defp setup_new_program(socket, provider) do
    changeset = Program.changeset(%Program{}, %{})

    socket
    |> assign(:page_title, "Create New Program")
    |> assign(:action, :new)
    |> assign(:provider, provider)
    |> assign(:program, nil)
    |> assign(:form, to_form(changeset))
  end

  defp add_form_data(socket) do
    categories = [
      "sports",
      "arts",
      "stem",
      "language",
      "music",
      "outdoor",
      "academic",
      "leadership"
    ]

    schedules =
      if socket.assigns[:program], do: load_schedules(socket.assigns.program), else: []

    locations =
      if socket.assigns[:program], do: load_locations(socket.assigns.program), else: []

    socket
    |> assign(:categories, categories)
    |> assign(:price_units, ["session", "week", "month", "program"])
    |> assign(:schedules, schedules)
    |> assign(:locations, locations)
  end

  @impl true
  def handle_event("validate", %{"program" => program_params} = params, socket) do
    # Extract schedules and locations from params if present
    schedules = Map.get(params, "schedules", socket.assigns.schedules)
    locations = Map.get(params, "locations", socket.assigns.locations)

    # Create changeset for validation
    changeset =
      case socket.assigns.action do
        :new ->
          %Program{}
          |> Program.changeset(program_params)
          |> Map.put(:action, :validate)
          |> validate_schedules(schedules)
          |> validate_locations(locations)

        :edit ->
          socket.assigns.program
          |> Program.changeset(program_params)
          |> Map.put(:action, :validate)
          |> validate_schedules(schedules)
          |> validate_locations(locations)
      end

    socket =
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:schedules, normalize_schedules(schedules))
      |> assign(:locations, normalize_locations(locations))

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_schedule", _params, socket) do
    # Add empty schedule to the list
    new_schedule = %{
      "start_date" => "",
      "end_date" => "",
      "start_time" => "",
      "end_time" => "",
      "recurrence_pattern" => "",
      "days_of_week" => []
    }

    schedules = socket.assigns.schedules ++ [new_schedule]
    {:noreply, assign(socket, :schedules, schedules)}
  end

  @impl true
  def handle_event("remove_schedule", %{"index" => index}, socket) do
    index = String.to_integer(index)
    schedules = List.delete_at(socket.assigns.schedules, index)
    {:noreply, assign(socket, :schedules, schedules)}
  end

  @impl true
  def handle_event("add_location", _params, socket) do
    # Add empty location to the list
    new_location = %{
      "name" => "",
      "is_virtual" => false,
      "address_line1" => "",
      "address_line2" => "",
      "city" => "",
      "state" => "",
      "postal_code" => "",
      "country" => "USA",
      "virtual_link" => "",
      "accessibility_notes" => ""
    }

    locations = socket.assigns.locations ++ [new_location]
    {:noreply, assign(socket, :locations, locations)}
  end

  @impl true
  def handle_event("remove_location", %{"index" => index}, socket) do
    index = String.to_integer(index)
    locations = List.delete_at(socket.assigns.locations, index)
    {:noreply, assign(socket, :locations, locations)}
  end

  @impl true
  def handle_event("toggle_virtual_location", %{"index" => index}, socket) do
    index = String.to_integer(index)
    locations = socket.assigns.locations

    updated_locations =
      List.update_at(locations, index, fn location ->
        Map.put(location, "is_virtual", !Map.get(location, "is_virtual", false))
      end)

    {:noreply, assign(socket, :locations, updated_locations)}
  end

  @impl true
  def handle_event("save", %{"program" => program_params}, socket) do
    case socket.assigns.action do
      :new ->
        create_program(socket, program_params)

      :edit ->
        update_program(socket, program_params)
    end
  end

  # Private helper functions

  defp get_provider_by_user_id(user_id) do
    Repo.one(from p in Provider, where: p.user_id == ^user_id)
  end

  defp get_program_for_editing(program_id, provider_id) do
    Program
    |> where([p], p.id == ^program_id)
    |> where([p], p.provider_id == ^provider_id)
    |> where([p], is_nil(p.archived_at))
    |> Repo.one()
  end

  defp create_program(socket, program_params) do
    # Load provider entity from database
    provider = Repo.get!(Provider, socket.assigns.provider.id)

    # Convert provider to domain entity
    provider_entity = %PrimeYouth.ProgramCatalog.Domain.Entities.Provider{
      id: provider.id,
      name: provider.name,
      email: provider.email,
      user_id: provider.user_id,
      is_verified: provider.is_verified,
      is_prime_youth: provider.is_prime_youth
    }

    # Build program attributes
    attrs = %{
      title: program_params["title"],
      description: program_params["description"],
      provider_id: provider.id,
      category: program_params["category"],
      age_range: %{
        min_age: parse_integer(program_params["age_min"] || "0", 0),
        max_age: parse_integer(program_params["age_max"] || "0", 0)
      },
      capacity: parse_integer(program_params["capacity"] || "0", 0),
      pricing: %{
        amount: parse_decimal(program_params["price_amount"]),
        currency: program_params["price_currency"] || "USD",
        unit: program_params["price_unit"] || "session",
        has_discount: program_params["has_discount"] == "true"
      }
    }

    # Use CreateProgram use case
    case CreateProgram.execute(attrs, provider_entity) do
      {:ok, _program} ->
        socket =
          socket
          |> put_flash(:info, "Program created successfully.")
          |> redirect(to: ~p"/provider/dashboard")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create program: #{inspect(reason)}")

        {:noreply, assign(socket, :form, to_form(Program.changeset(%Program{}, program_params)))}
    end
  end

  defp update_program(socket, program_params) do
    # Load provider entity from database
    provider = Repo.get!(Provider, socket.assigns.provider.id)

    # Convert provider to domain entity
    provider_entity = %PrimeYouth.ProgramCatalog.Domain.Entities.Provider{
      id: provider.id,
      name: provider.name,
      email: provider.email,
      user_id: provider.user_id,
      is_verified: provider.is_verified,
      is_prime_youth: provider.is_prime_youth
    }

    # Convert Ecto program to domain entity
    program_entity = %PrimeYouth.ProgramCatalog.Domain.Entities.Program{
      id: socket.assigns.program.id,
      title: socket.assigns.program.title,
      description: socket.assigns.program.description,
      provider_id: socket.assigns.program.provider_id,
      category: socket.assigns.program.category,
      age_range: %{
        min_age: socket.assigns.program.age_min,
        max_age: socket.assigns.program.age_max
      },
      capacity: socket.assigns.program.capacity,
      current_enrollment: socket.assigns.program.current_enrollment,
      pricing: %{
        amount: socket.assigns.program.price_amount,
        currency: socket.assigns.program.price_currency,
        unit: socket.assigns.program.price_unit,
        has_discount: socket.assigns.program.has_discount
      },
      status: socket.assigns.program.status,
      is_prime_youth: socket.assigns.program.is_prime_youth
    }

    # Build update attributes
    attrs = %{
      title: program_params["title"],
      description: program_params["description"],
      category: program_params["category"],
      age_range: %{
        min_age: parse_integer(program_params["age_min"] || "0", 0),
        max_age: parse_integer(program_params["age_max"] || "0", 0)
      },
      capacity: parse_integer(program_params["capacity"] || "0", 0),
      pricing: %{
        amount: parse_decimal(program_params["price_amount"]),
        currency: program_params["price_currency"] || "USD",
        unit: program_params["price_unit"] || "session",
        has_discount: program_params["has_discount"] == "true"
      }
    }

    # Use UpdateProgram use case
    case UpdateProgram.execute(program_entity, attrs, provider_entity) do
      {:ok, _program} ->
        socket =
          socket
          |> put_flash(:info, "Program updated successfully.")
          |> redirect(to: ~p"/provider/dashboard")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to update program: #{inspect(reason)}")

        {:noreply,
         assign(socket, :form, to_form(Program.changeset(socket.assigns.program, program_params)))}
    end
  end

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end

  defp parse_decimal(value) when is_number(value) do
    Decimal.new(to_string(value))
  end

  defp parse_decimal(%Decimal{} = value), do: value
  defp parse_decimal(_), do: Decimal.new("0")

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _} -> integer
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default

  # Schedule and location helper functions

  defp load_schedules(%Program{id: program_id}) do
    # Load existing schedules from database
    alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.ProgramSchedule

    Repo.all(from s in ProgramSchedule, where: s.program_id == ^program_id)
    |> Enum.map(&schedule_to_map/1)
  end

  defp load_schedules(_), do: []

  defp schedule_to_map(schedule) do
    %{
      "id" => schedule.id,
      "start_date" => Date.to_string(schedule.start_date),
      "end_date" => Date.to_string(schedule.end_date),
      "start_time" => Time.to_string(schedule.start_time),
      "end_time" => Time.to_string(schedule.end_time),
      "recurrence_pattern" => schedule.recurrence_pattern,
      "days_of_week" => schedule.days_of_week || []
    }
  end

  defp load_locations(%Program{id: program_id}) do
    # Load existing locations from database
    alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Location

    Repo.all(from l in Location, where: l.program_id == ^program_id)
    |> Enum.map(&location_to_map/1)
  end

  defp load_locations(_), do: []

  defp location_to_map(location) do
    %{
      "id" => location.id,
      "name" => location.name,
      "is_virtual" => location.is_virtual,
      "address_line1" => location.address_line1 || "",
      "address_line2" => location.address_line2 || "",
      "city" => location.city || "",
      "state" => location.state || "",
      "postal_code" => location.postal_code || "",
      "country" => location.country || "USA",
      "virtual_link" => location.virtual_link || "",
      "accessibility_notes" => location.accessibility_notes || ""
    }
  end

  defp normalize_schedules(schedules) when is_map(schedules) do
    # Convert map with integer keys to list
    schedules
    |> Enum.map(fn {_key, value} -> value end)
    |> Enum.sort_by(fn schedule -> Map.get(schedule, "start_date", "") end)
  end

  defp normalize_schedules(schedules) when is_list(schedules), do: schedules
  defp normalize_schedules(_), do: []

  defp normalize_locations(locations) when is_map(locations) do
    # Convert map with integer keys to list
    locations
    |> Enum.map(fn {_key, value} -> value end)
  end

  defp normalize_locations(locations) when is_list(locations), do: locations
  defp normalize_locations(_), do: []

  defp validate_schedules(changeset, schedules) do
    schedule_list = normalize_schedules(schedules)

    if Enum.empty?(schedule_list) do
      Ecto.Changeset.add_error(changeset, :schedules, "at least one schedule is required")
    else
      errors =
        schedule_list
        |> Enum.with_index()
        |> Enum.flat_map(fn {schedule, index} ->
          validate_schedule_item(schedule, index)
        end)

      apply_validation_errors(changeset, errors)
    end
  end

  defp apply_validation_errors(changeset, []), do: changeset

  defp apply_validation_errors(changeset, errors) do
    Enum.reduce(errors, changeset, fn {field, message}, acc ->
      Ecto.Changeset.add_error(acc, field, message)
    end)
  end

  defp validate_schedule_item(schedule, _index) do
    errors = []

    # Validate required fields
    errors =
      if blank?(schedule["start_date"]) do
        [{:schedules, "start date is required"} | errors]
      else
        errors
      end

    errors =
      if blank?(schedule["end_date"]) do
        [{:schedules, "end date is required"} | errors]
      else
        errors
      end

    errors =
      if blank?(schedule["start_time"]) do
        [{:schedules, "start time is required"} | errors]
      else
        errors
      end

    errors =
      if blank?(schedule["end_time"]) do
        [{:schedules, "end time is required"} | errors]
      else
        errors
      end

    errors =
      if blank?(schedule["recurrence_pattern"]) do
        [{:schedules, "recurrence pattern is required"} | errors]
      else
        errors
      end

    errors
  end

  defp validate_locations(changeset, locations) do
    location_list = normalize_locations(locations)

    if Enum.empty?(location_list) do
      Ecto.Changeset.add_error(changeset, :locations, "at least one location is required")
    else
      errors =
        location_list
        |> Enum.with_index()
        |> Enum.flat_map(fn {location, index} ->
          validate_location_item(location, index)
        end)

      apply_validation_errors(changeset, errors)
    end
  end

  defp validate_location_item(location, _index) do
    errors = []

    # Validate required fields
    errors =
      if blank?(location["name"]) do
        [{:locations, "location name is required"} | errors]
      else
        errors
      end

    # Validate virtual location requirements
    is_virtual = Map.get(location, "is_virtual", false)

    errors =
      if is_virtual && blank?(location["virtual_link"]) do
        [{:locations, "virtual link is required for online locations"} | errors]
      else
        errors
      end

    errors
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false
end
