defmodule PrimeYouth.Auth.Adapters.Driven.EctoRepository do
  @moduledoc """
  Adapter implementing Repository port using Ecto.
  Consolidates all persistence operations: users, session tokens, email tokens, password reset tokens.
  Translates between domain User entities and Ecto schemas.
  """

  @behaviour PrimeYouth.Auth.Ports.Repository

  import Ecto.Query

  alias PrimeYouth.Auth.Domain.User, as: DomainUser
  alias PrimeYouth.Auth.Infrastructure.User, as: UserSchema
  alias PrimeYouth.Auth.Infrastructure.UserToken
  alias PrimeYouth.Repo

  # ============================================================================
  # User Operations
  # ============================================================================

  @impl true
  def find_by_id(id) do
    case Repo.get(UserSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def find_by_email(email) do
    case Repo.get_by(UserSchema, email: email) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def save(%DomainUser{} = domain_user) do
    attrs = to_schema_attrs(domain_user)

    changeset = UserSchema.create_changeset(%UserSchema{}, attrs)

    case Repo.insert(changeset) do
      {:ok, schema} -> {:ok, to_domain(schema)}
      error -> error
    end
  end

  @impl true
  def update(%DomainUser{} = domain_user) do
    schema = to_schema(domain_user)
    changeset = Ecto.Changeset.change(schema)

    case Repo.update(changeset) do
      {:ok, updated_schema} -> {:ok, to_domain(updated_schema)}
      error -> error
    end
  end

  @impl true
  def update_email(%DomainUser{} = domain_user, new_email) do
    schema = Repo.get!(UserSchema, domain_user.id)
    changeset = UserSchema.email_changeset(schema, %{email: new_email})

    case Repo.update(changeset) do
      {:ok, updated_schema} -> {:ok, to_domain(updated_schema)}
      error -> error
    end
  end

  @impl true
  def update_password(%DomainUser{} = domain_user, new_hashed_password) do
    schema = Repo.get!(UserSchema, domain_user.id)

    changeset =
      schema
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_change(:hashed_password, new_hashed_password)

    case Repo.update(changeset) do
      {:ok, updated_schema} -> {:ok, to_domain(updated_schema)}
      error -> error
    end
  end

  # ============================================================================
  # Session Token Operations
  # ============================================================================

  @impl true
  def generate_session_token(%DomainUser{} = domain_user) do
    schema_user = to_schema(domain_user)
    {token, user_token} = UserToken.build_session_token(schema_user)
    Repo.insert!(user_token)
    {:ok, token}
  rescue
    e -> {:error, e}
  end

  @impl true
  def find_by_session_token(token) do
    query =
      from u in UserSchema,
        join: t in UserToken,
        on: t.user_id == u.id,
        where: t.token == ^token and t.context == "session",
        select: {u, t.inserted_at}

    case Repo.one(query) do
      {user, token_inserted_at} -> {:ok, {to_domain(user), token_inserted_at}}
      nil -> {:error, :not_found}
    end
  end

  @impl true
  def delete_session_token(token) do
    Repo.delete_all(from(t in UserToken, where: t.token == ^token and t.context == "session"))
    :ok
  rescue
    e -> {:error, e}
  end

  @impl true
  def delete_all_session_tokens_for_user(%DomainUser{} = domain_user) do
    Repo.delete_all(
      from(t in UserToken, where: t.user_id == ^domain_user.id and t.context == "session")
    )

    :ok
  rescue
    e -> {:error, e}
  end

  # ============================================================================
  # Email Token Operations (confirmation, magic link, change email)
  # ============================================================================

  @impl true
  def generate_email_token(%DomainUser{} = domain_user, context) do
    schema_user = to_schema(domain_user)
    context_string = email_context_to_string(context)
    {encoded_token, user_token} = UserToken.build_email_token(schema_user, context_string)
    Repo.insert!(user_token)
    {:ok, encoded_token}
  rescue
    e -> {:error, e}
  end

  @impl true
  def verify_email_token(token, context) do
    context_string = email_context_to_string(context)

    result =
      case context do
        :magic_link ->
          with {:ok, query} <- UserToken.verify_magic_link_token_query(token) do
            case Repo.one(query) do
              {user, _token} -> {:ok, to_domain(user)}
              nil -> {:error, :invalid_token}
            end
          end

        _ ->
          with {:ok, query} <- UserToken.verify_change_email_token_query(token, context_string) do
            case Repo.one(query) do
              nil ->
                {:error, :invalid_token}

              token_record ->
                user = Repo.get!(UserSchema, token_record.user_id)
                {:ok, to_domain(user)}
            end
          end
      end

    case result do
      {:ok, _} = success -> success
      {:error, _} = error -> error
      :error -> {:error, :invalid_token}
    end
  end

  @impl true
  def delete_email_tokens_for_user(%DomainUser{} = domain_user, context) do
    context_string = email_context_to_string(context)

    Repo.delete_all(
      from(t in UserToken, where: t.user_id == ^domain_user.id and t.context == ^context_string)
    )

    :ok
  rescue
    e -> {:error, e}
  end

  # ============================================================================
  # Password Reset Token Operations
  # ============================================================================

  @impl true
  def generate_password_reset_token(%DomainUser{} = domain_user) do
    schema_user = to_schema(domain_user)
    {encoded_token, user_token} = UserToken.build_email_token(schema_user, "reset_password")
    Repo.insert!(user_token)
    {:ok, encoded_token}
  rescue
    e -> {:error, e}
  end

  @impl true
  def verify_password_reset_token(token) do
    case UserToken.verify_change_email_token_query(token, "reset_password") do
      {:ok, query} ->
        case Repo.one(query) do
          nil ->
            {:error, :invalid_token}

          token_record ->
            user = Repo.get!(UserSchema, token_record.user_id)
            {:ok, to_domain(user)}
        end

      :error ->
        {:error, :invalid_token}
    end
  end

  @impl true
  def delete_password_reset_tokens_for_user(%DomainUser{} = domain_user) do
    Repo.delete_all(
      from(t in UserToken, where: t.user_id == ^domain_user.id and t.context == "reset_password")
    )

    :ok
  rescue
    e -> {:error, e}
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp to_domain(%UserSchema{} = schema) do
    %DomainUser{
      id: schema.id,
      email: schema.email,
      first_name: schema.first_name,
      last_name: schema.last_name,
      hashed_password: schema.hashed_password,
      confirmed_at: schema.confirmed_at,
      authenticated_at: schema.authenticated_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp to_schema(%DomainUser{} = domain_user) do
    %UserSchema{
      id: domain_user.id,
      email: domain_user.email,
      first_name: domain_user.first_name,
      last_name: domain_user.last_name,
      hashed_password: domain_user.hashed_password,
      confirmed_at: domain_user.confirmed_at,
      authenticated_at: domain_user.authenticated_at,
      inserted_at: domain_user.inserted_at,
      updated_at: domain_user.updated_at
    }
  end

  defp to_schema_attrs(%DomainUser{} = domain), do: Map.from_struct(domain)

  defp email_context_to_string(:confirmation), do: "confirm"
  defp email_context_to_string(:magic_link), do: "login"
  defp email_context_to_string(:change_email), do: "change:email"
end
