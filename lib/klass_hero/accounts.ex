defmodule KlassHero.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  alias KlassHero.Accounts.{EventPublisher, User, UserNotifier, UserToken}
  alias KlassHero.Repo

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    case %User{}
         |> User.registration_changeset(attrs)
         |> Repo.insert() do
      {:ok, user} ->
        EventPublisher.publish_user_registered(user, registration_source: :web)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `KlassHero.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"
    previous_email = user.email

    Ecto.Multi.new()
    |> Ecto.Multi.run(:verify_token, fn _repo, _ ->
      UserToken.verify_change_email_token_query(token, context)
    end)
    |> Ecto.Multi.run(:fetch_token, fn repo, %{verify_token: query} ->
      case repo.one(query) do
        %UserToken{sent_to: email} = token -> {:ok, {token, email}}
        nil -> {:error, :token_not_found}
      end
    end)
    |> Ecto.Multi.run(:update_email, fn repo, %{fetch_token: {_token, email}} ->
      user
      |> User.email_changeset(%{email: email})
      |> repo.update()
    end)
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{update_email: updated_user} ->
      from(UserToken, where: [user_id: ^updated_user.id, context: ^context])
    end)
    |> Ecto.Multi.run(:publish_event, fn _repo, %{update_email: updated_user} ->
      EventPublisher.publish_user_email_changed(updated_user, previous_email: previous_email)
      {:ok, updated_user}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{publish_event: user}} -> {:ok, user}
      {:error, :verify_token, _reason, _} -> {:error, :invalid_token}
      {:error, :fetch_token, _reason, _} -> {:error, :invalid_token}
      {:error, :update_email, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `KlassHero.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  @doc """
  Updates the user password, requiring sudo mode.

  Returns `{:error, :sudo_required}` if user is not in sudo mode.
  Otherwise behaves like `update_user_password/2`.

  ## Examples

      iex> update_user_password_with_sudo(user_in_sudo_mode, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password_with_sudo(user_not_in_sudo_mode, %{password: ...})
      {:error, :sudo_required}

  """
  def update_user_password_with_sudo(user, attrs) do
    if sudo_mode?(user) do
      update_user_password(user, attrs)
    else
      {:error, :sudo_required}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user locale.

  ## Examples

      iex> change_user_locale(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_locale(user, attrs \\ %{}) do
    User.locale_changeset(user, attrs)
  end

  @doc """
  Updates the user locale preference.

  ## Examples

      iex> update_user_locale(user, %{locale: "de"})
      {:ok, %User{locale: "de"}}

      iex> update_user_locale(user, %{locale: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_locale(user, attrs) do
    user
    |> User.locale_changeset(attrs)
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        case user
             |> User.confirm_changeset()
             |> update_user_and_delete_all_tokens() do
          {:ok, {confirmed_user, tokens}} ->
            EventPublisher.publish_user_confirmed(confirmed_user,
              confirmation_method: :magic_link
            )

            {:ok, {confirmed_user, tokens}}

          error ->
            error
        end

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:update_user, changeset)
    |> Ecto.Multi.run(:fetch_tokens, fn repo, %{update_user: user} ->
      tokens = repo.all_by(UserToken, user_id: user.id)
      {:ok, tokens}
    end)
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{fetch_tokens: tokens} ->
      from(t in UserToken, where: t.id in ^Enum.map(tokens, & &1.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_user: user, fetch_tokens: tokens}} -> {:ok, {user, tokens}}
      {:error, :update_user, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  ## GDPR Data Export

  @doc """
  Exports all personal data for the given user in GDPR-compliant format.

  Returns a map containing all user data that can be serialized to JSON.
  """
  def export_user_data(%User{} = user) do
    %{
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      user: %{
        id: user.id,
        email: user.email,
        name: user.name,
        avatar: user.avatar,
        confirmed_at: user.confirmed_at && DateTime.to_iso8601(user.confirmed_at),
        created_at: user.inserted_at && DateTime.to_iso8601(user.inserted_at),
        updated_at: user.updated_at && DateTime.to_iso8601(user.updated_at)
      }
    }
  end

  ## GDPR Account Anonymization

  @doc """
  Anonymizes a user account for GDPR deletion requests.

  This function:
  1. Stores the previous email for audit trail
  2. Invalidates all session tokens (logs out from all devices)
  3. Replaces PII with anonymized values
  4. Publishes `user_anonymized` domain event

  Downstream contexts (Identity, Participation) react to the `user_anonymized`
  event asynchronously to anonymize their own data.

  ## Examples

      iex> anonymize_user(user)
      {:ok, %User{email: "deleted_123@anonymized.local"}}

      iex> anonymize_user(nil)
      {:error, :user_not_found}

  """
  def anonymize_user(%User{} = user) do
    previous_email = user.email

    Ecto.Multi.new()
    |> Ecto.Multi.update(:anonymize_user, User.anonymize_changeset(user))
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{anonymize_user: anonymized_user} ->
      from(t in UserToken, where: t.user_id == ^anonymized_user.id)
    end)
    |> Ecto.Multi.run(:publish_event, fn _repo, %{anonymize_user: anonymized_user} ->
      EventPublisher.publish_user_anonymized(anonymized_user, previous_email: previous_email)
      {:ok, anonymized_user}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{publish_event: user}} -> {:ok, user}
      {:error, :anonymize_user, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def anonymize_user(nil), do: {:error, :user_not_found}

  @doc """
  Deletes (anonymizes) user account after password verification.

  This function orchestrates the complete account deletion flow:
  1. Verifies user is in sudo mode
  2. Verifies password matches
  3. Anonymizes the user account

  ## Returns

    * `{:ok, %User{}}` - Account successfully anonymized
    * `{:error, :sudo_required}` - User is not in sudo mode
    * `{:error, :invalid_password}` - Password doesn't match
    * `{:error, reason}` - Anonymization failed

  ## Examples

      iex> delete_account(user_in_sudo_mode, "correct_password")
      {:ok, %User{email: "deleted_123@anonymized.local"}}

      iex> delete_account(user_not_in_sudo_mode, "password")
      {:error, :sudo_required}

      iex> delete_account(user_in_sudo_mode, "wrong_password")
      {:error, :invalid_password}

  """
  def delete_account(%User{} = user, password) when is_binary(password) do
    with true <- sudo_mode?(user),
         %User{} <- get_user_by_email_and_password(user.email, password) do
      anonymize_user(user)
    else
      false -> {:error, :sudo_required}
      nil -> {:error, :invalid_password}
    end
  end
end
