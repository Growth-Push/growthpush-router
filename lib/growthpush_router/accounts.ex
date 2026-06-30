defmodule GrowthPushRouter.Accounts do
  @moduledoc false

  import Ecto.Query, warn: false

  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Repo

  @doc """
  Lists users visible to an admin actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, _user} = Accounts.create_user(admin, %{"email" => "list-doc@example.com", "name" => "List Doc"})
      iex> {:ok, users} = Accounts.list_users(admin, search: "list-doc")
      iex> Enum.map(users, & &1.email)
      ["list-doc@example.com"]

  """
  def list_users(admin_user, opts \\ [])

  def list_users(%User{} = admin_user, opts) do
    with :ok <- authorize_admin(admin_user) do
      {:ok, do_list_users(opts)}
    end
  end

  def list_users(_admin_user, _opts), do: {:error, :unauthorized}

  defp do_list_users(opts) do
    query = from(u in User)

    opts
    |> Enum.reduce(query, fn filter, q ->
      filter_query(q, [filter])
    end)
    |> order_by([u], asc: u.inserted_at)
    |> Repo.all()
    |> tag_runtime_roles()
  end

  @doc """
  Gets a user by id for session/auth lookups.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "get-doc@example.com", "name" => "Get Doc"})
      iex> Accounts.get_user(user.id).email
      "get-doc@example.com"

  """
  def get_user(nil), do: nil

  def get_user(id) do
    User
    |> Repo.get(id)
    |> tag_runtime_role()
  end

  @doc """
  Fetches a user for an admin actor.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "fetch-doc@example.com", "name" => "Fetch Doc"})
      iex> {:ok, fetched_user} = Accounts.fetch_user(admin, user.id)
      iex> fetched_user.email
      "fetch-doc@example.com"

  """
  def fetch_user(%User{} = admin_user, id) do
    with :ok <- authorize_admin(admin_user) do
      {:ok, User |> Repo.get!(id) |> tag_runtime_role()}
    end
  end

  def fetch_user(_admin_user, _id), do: {:error, :unauthorized}

  @doc """
  Gets a user by normalized email.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, _user} = Accounts.create_user(admin, %{"email" => "email-doc@example.com", "name" => "Email Doc"})
      iex> Accounts.get_user_by_email("EMAIL-DOC@example.com").name
      "Email Doc"

  """
  def get_user_by_email(email) when is_binary(email) do
    User
    |> filter_query(email: email)
    |> Repo.one()
    |> tag_runtime_role()
  end

  def get_user_by_email(_), do: nil

  @doc """
  Authenticates a user by email and password.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "auth-doc@example.com", "name" => "Auth Doc"})
      iex> {:ok, _user} = Accounts.set_initial_password(user, %{"password" => "strong-pass", "password_confirmation" => "strong-pass"})
      iex> {:ok, authenticated_user} = Accounts.authenticate_user("auth-doc@example.com", "strong-pass")
      iex> authenticated_user.email
      "auth-doc@example.com"

  """
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    email
    |> get_user_by_email()
    |> authenticate_user_password(password)
  end

  def authenticate_user(_, _), do: :error

  @doc """
  Creates a user as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "create-doc@example.com", "name" => "Create Doc"})
      iex> user.email
      "create-doc@example.com"

  """
  def create_user(%User{} = admin_user, attrs) do
    with :ok <- authorize_admin(admin_user) do
      do_create_user(attrs)
    end
  end

  def create_user(_admin_user, _attrs), do: {:error, :unauthorized}

  @doc """
  Updates a user as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "update-doc@example.com", "name" => "Update Doc"})
      iex> {:ok, updated_user} = Accounts.update_user(admin, user, %{"email" => "update-doc@example.com", "name" => "Updated Doc"})
      iex> updated_user.name
      "Updated Doc"

  """
  def update_user(%User{} = admin_user, %User{} = user, attrs) do
    with :ok <- authorize_admin(admin_user) do
      do_update_user(user, attrs)
    end
  end

  def update_user(_admin_user, _user, _attrs), do: {:error, :unauthorized}

  @doc """
  Deletes a user as an admin operation.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "delete-doc@example.com", "name" => "Delete Doc"})
      iex> {:ok, deleted_user} = Accounts.delete_user(admin, user)
      iex> Accounts.get_user(deleted_user.id)
      nil

  """
  def delete_user(%User{} = admin_user, %User{} = user) do
    with :ok <- authorize_admin(admin_user) do
      user
      |> Repo.delete()
      |> tag_runtime_role_result()
    end
  end

  def delete_user(_admin_user, _user), do: {:error, :unauthorized}

  @doc """
  Creates or updates the bootstrap admin user from seed data.

  This bypasses admin actor authorization and is intended only for seeds/bootstrap.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> {:ok, user} = Accounts.upsert_seeded_admin(%{"email" => "seed-doc@example.com", "name" => "Seed Doc"})
      iex> user.email
      "seed-doc@example.com"

  """
  def upsert_seeded_admin(attrs) do
    case get_user_by_email(fetch_email(attrs)) do
      nil -> do_create_user(attrs)
      %User{} = user -> do_update_user(user, attrs)
    end
  end

  defp fetch_email(%{} = attrs), do: attrs[:email] || attrs["email"]

  defp do_create_user(attrs) do
    %User{}
    |> User.admin_changeset(attrs)
    |> Repo.insert()
    |> tag_runtime_role_result()
  end

  defp do_update_user(%User{} = user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
    |> tag_runtime_role_result()
  end

  @doc """
  Returns an admin user changeset.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> changeset = Accounts.change_user(%User{}, %{"email" => "change-doc@example.com", "name" => "Change Doc"})
      iex> changeset.valid?
      true

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.admin_changeset(user, attrs)
  end

  @doc """
  Returns a password changeset.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> changeset = Accounts.change_user_password(%User{}, %{"password" => "strong-pass", "password_confirmation" => "strong-pass"})
      iex> changeset.valid?
      true

  """
  def change_user_password(%User{} = user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  @doc """
  Sets a user's initial password.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "password-doc@example.com", "name" => "Password Doc"})
      iex> {:ok, updated_user} = Accounts.set_initial_password(user, %{"password" => "strong-pass", "password_confirmation" => "strong-pass"})
      iex> User.password_set?(updated_user)
      true

  """
  def set_initial_password(email, attrs) when is_binary(email) do
    case get_user_by_email(email) do
      nil ->
        :error

      %User{} = user ->
        set_initial_password(user, attrs)
    end
  end

  def set_initial_password(%User{} = user, attrs) do
    if User.password_set?(user) do
      {:error, :password_already_set}
    else
      set_password(user, attrs)
    end
  end

  @doc """
  Clears a user's password so they can define it again on next access.

  ## Examples

      iex> alias GrowthPushRouter.Accounts
      iex> alias GrowthPushRouter.Accounts.User
      iex> admin = %User{email: "admin@example.test"}
      iex> {:ok, user} = Accounts.create_user(admin, %{"email" => "reset-doc@example.com", "name" => "Reset Doc"})
      iex> {:ok, user} = Accounts.set_initial_password(user, %{"password" => "strong-pass", "password_confirmation" => "strong-pass"})
      iex> {:ok, reset_user} = Accounts.reset_user_password(admin, user)
      iex> User.password_set?(reset_user)
      false

  """
  def reset_user_password(%User{} = admin_user, %User{} = user) do
    with :ok <- authorize_admin(admin_user) do
      do_reset_user_password(user)
    end
  end

  def reset_user_password(_admin_user, _user), do: {:error, :unauthorized}

  defp do_reset_user_password(%User{} = user) do
    user
    |> User.clear_password_changeset()
    |> Repo.update()
    |> tag_runtime_role_result()
  end

  defp authorize_admin(%User{} = user) do
    case user do
      %User{is_admin: true} -> :ok
      %User{} -> if User.admin?(user), do: :ok, else: {:error, :unauthorized}
    end
  end

  defp set_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
    |> tag_runtime_role_result()
  end

  defp authenticate_user_password(nil, password) do
    User.valid_password?(nil, password)
    :error
  end

  defp authenticate_user_password(%User{hashed_password: nil} = user, _password) do
    {:error, :password_not_set, user}
  end

  defp authenticate_user_password(%User{hashed_password: ""} = user, _password) do
    {:error, :password_not_set, user}
  end

  defp authenticate_user_password(%User{} = user, password) do
    user
    |> User.valid_password?(password)
    |> authenticated_user(user)
  end

  defp authenticated_user(true, %User{} = user), do: {:ok, tag_runtime_role(user)}
  defp authenticated_user(false, %User{}), do: :error

  defp tag_runtime_role(%User{} = user), do: User.with_runtime_role(user)
  defp tag_runtime_role(nil), do: nil

  defp tag_runtime_roles(users) when is_list(users), do: Enum.map(users, &tag_runtime_role/1)

  defp tag_runtime_role_result({:ok, %User{} = user}), do: {:ok, tag_runtime_role(user)}
  defp tag_runtime_role_result(other), do: other

  defp filter_query(query, email: email) when is_binary(email) do
    where(query, [u], u.email == ^User.normalize_email(email))
  end

  defp filter_query(query, search: search) when is_binary(search) do
    pattern = "%#{String.trim(search)}%"

    if pattern == "%%" do
      query
    else
      where(
        query,
        [u],
        ilike(u.email, ^pattern) or ilike(u.name, ^pattern) or ilike(u.company, ^pattern)
      )
    end
  end

  defp filter_query(query, _), do: query
end
