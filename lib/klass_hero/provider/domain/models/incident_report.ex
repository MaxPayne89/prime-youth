defmodule KlassHero.Provider.Domain.Models.IncidentReport do
  @moduledoc """
  Domain model for an incident report submitted by a provider.

  Polymorphic by scope: a report is tied to exactly one of `program_id`
  or `session_id`, never both. This invariant is enforced in `new/1` and
  backed at the DB layer by a CHECK constraint.

  This is a pure domain model with no persistence or infrastructure
  concerns. Validation happens at the domain boundary.

  ## Fields

  - `id` - Unique identifier for the report
  - `provider_profile_id` - Reference to the provider submitting the report
  - `reporter_user_id` - ID of the user submitting the report
  - `program_id` - Reference to the program (when scoped to a program)
  - `session_id` - Reference to the session (when scoped to a session)
  - `category` - Incident category (e.g. `:safety_concern`, `:injury`)
  - `severity` - Severity level (`:low`, `:medium`, `:high`, `:critical`)
  - `description` - Free-text description (at least 10 characters)
  - `occurred_at` - When the incident occurred (cannot be in the future)
  - `photo_url` - Storage key for an optional attached photo
  - `original_filename` - Original filename of the uploaded photo
  - `inserted_at` - When the record was created
  - `updated_at` - When the record was last updated
  """

  @valid_categories [
    :safety_concern,
    :behavioral_issue,
    :injury,
    :property_damage,
    :policy_violation,
    :other
  ]

  @valid_severities [:low, :medium, :high, :critical]

  @min_description_length 10

  @enforce_keys [
    :id,
    :provider_profile_id,
    :reporter_user_id,
    :category,
    :severity,
    :description,
    :occurred_at
  ]

  defstruct [
    :id,
    :provider_profile_id,
    :reporter_user_id,
    :program_id,
    :session_id,
    :category,
    :severity,
    :description,
    :occurred_at,
    :photo_url,
    :original_filename,
    :inserted_at,
    :updated_at
  ]

  @type category ::
          :safety_concern
          | :behavioral_issue
          | :injury
          | :property_damage
          | :policy_violation
          | :other

  @type severity :: :low | :medium | :high | :critical

  @type t :: %__MODULE__{
          id: String.t(),
          provider_profile_id: String.t(),
          reporter_user_id: String.t(),
          program_id: String.t() | nil,
          session_id: String.t() | nil,
          category: category(),
          severity: severity(),
          description: String.t(),
          occurred_at: DateTime.t(),
          photo_url: String.t() | nil,
          original_filename: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc "Returns the list of valid incident categories."
  def valid_categories, do: @valid_categories

  @doc "Returns the list of valid incident severities."
  def valid_severities, do: @valid_severities

  @doc "Plain English label for a category atom."
  @spec category_label(category()) :: String.t()
  def category_label(:safety_concern), do: "Safety concern"
  def category_label(:behavioral_issue), do: "Behavioral issue"
  def category_label(:injury), do: "Injury"
  def category_label(:property_damage), do: "Property damage"
  def category_label(:policy_violation), do: "Policy violation"
  def category_label(:other), do: "Other"

  @doc "Plain English label for a severity atom."
  @spec severity_label(severity()) :: String.t()
  def severity_label(:low), do: "Low"
  def severity_label(:medium), do: "Medium"
  def severity_label(:high), do: "High"
  def severity_label(:critical), do: "Critical"

  @doc """
  Creates a new IncidentReport with validation.

  Returns `{:ok, report}` when all invariants hold, or `{:error, keyword}`
  with the first validation failure encountered.
  """
  @spec new(map()) :: {:ok, t()} | {:error, keyword()}
  def new(attrs) when is_map(attrs) do
    with :ok <- validate_target(attrs),
         :ok <- validate_category(attrs),
         :ok <- validate_severity(attrs),
         :ok <- validate_description(attrs),
         :ok <- validate_occurred_at(attrs),
         :ok <- validate_photo_pair(attrs) do
      {:ok,
       %__MODULE__{
         id: attrs[:id],
         provider_profile_id: attrs[:provider_profile_id],
         reporter_user_id: attrs[:reporter_user_id],
         program_id: attrs[:program_id],
         session_id: attrs[:session_id],
         category: attrs[:category],
         severity: attrs[:severity],
         description: attrs[:description],
         occurred_at: attrs[:occurred_at],
         photo_url: attrs[:photo_url],
         original_filename: attrs[:original_filename],
         inserted_at: attrs[:inserted_at],
         updated_at: attrs[:updated_at]
       }}
    end
  end

  defp validate_target(attrs) do
    program_id = Map.get(attrs, :program_id)
    session_id = Map.get(attrs, :session_id)

    case {program_id, session_id} do
      {pid, nil} when is_binary(pid) -> :ok
      {nil, sid} when is_binary(sid) -> :ok
      _ -> {:error, [target: "exactly one of program_id or session_id must be set"]}
    end
  end

  defp validate_category(%{category: category}) when category in @valid_categories, do: :ok
  defp validate_category(_attrs), do: {:error, [category: "is invalid"]}

  defp validate_severity(%{severity: severity}) when severity in @valid_severities, do: :ok
  defp validate_severity(_attrs), do: {:error, [severity: "is invalid"]}

  defp validate_description(%{description: d}) when is_binary(d) do
    if String.length(d) >= @min_description_length do
      :ok
    else
      {:error, [description: "must be at least #{@min_description_length} characters"]}
    end
  end

  defp validate_description(_attrs),
    do: {:error, [description: "must be at least #{@min_description_length} characters"]}

  defp validate_occurred_at(%{occurred_at: %DateTime{} = occurred_at}) do
    case DateTime.compare(occurred_at, DateTime.utc_now()) do
      :gt -> {:error, [occurred_at: "cannot be in the future"]}
      _ -> :ok
    end
  end

  defp validate_occurred_at(_attrs), do: {:error, [occurred_at: "must be a DateTime"]}

  defp validate_photo_pair(attrs) do
    case {Map.get(attrs, :photo_url), Map.get(attrs, :original_filename)} do
      {nil, _} -> :ok
      {url, name} when is_binary(url) and is_binary(name) -> :ok
      {url, _} when is_binary(url) -> {:error, [original_filename: "is required when photo_url is set"]}
      _ -> :ok
    end
  end
end
