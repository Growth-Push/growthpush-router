defmodule GrowthPushRouter.Accounts.User do
  @moduledoc false

  use Ecto.Schema
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  import Ecto.Changeset

  alias GrowthPushRouter.Repo

  @required ~w(email name)a
  @optional ~w(company)a
  @password_required ~w(password)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :name, :string
    field :company, :string
    field :hashed_password, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :is_admin, :boolean, virtual: true, default: false

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for admin-managed user fields.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> changeset = User.admin_changeset(%User{}, %{"email" => "USER@example.com", "name" => "User"})
      iex> changeset.valid?
      true
      iex> Ecto.Changeset.get_change(changeset, :email)
      "user@example.com"

  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, @required ++ @optional)
    |> update_change(:email, &normalize_email/1)
    |> validate_required(@required, message: dgettext("errors", ".cant_be_blank"))
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: dgettext("errors", ".wrong_email"))
    |> validate_length(:email, max: 160, message: dgettext("errors", ".too_long", count: 160))
    |> validate_length(:name, max: 160, message: dgettext("errors", ".too_long", count: 160))
    |> validate_length(:company, max: 160, message: dgettext("errors", ".too_long", count: 160))
    |> unsafe_validate_unique(:email, Repo, message: dgettext("errors", ".email_unique_error"))
    |> unique_constraint(:email,
      name: :users_email_lower_index,
      message: dgettext("errors", ".email_unique_error")
    )
  end

  @doc """
  Builds a password changeset and hashes valid passwords.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> changeset = User.password_changeset(%User{}, %{"password" => "strong-pass", "password_confirmation" => "strong-pass"})
      iex> changeset.valid?
      true
      iex> is_binary(Ecto.Changeset.get_change(changeset, :hashed_password))
      true

  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, @password_required)
    |> validate_required(@password_required, message: dgettext("errors", ".cant_be_blank"))
    |> validate_length(:password, min: 8, message: dgettext("errors", ".password_too_short"))
    |> validate_length(:password, max: 72, message: dgettext("errors", ".password_too_long"))
    |> validate_confirmation(:password,
      message: dgettext("errors", ".password_confirmation_mismatch")
    )
    |> maybe_hash_password()
  end

  @doc """
  Clears a user's password hash.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> changeset = User.clear_password_changeset(%User{hashed_password: "hash"})
      iex> Ecto.Changeset.get_change(changeset, :hashed_password)
      nil

  """
  def clear_password_changeset(user) do
    change(user, hashed_password: nil)
  end

  @doc """
  Verifies a plain password against a user's password hash.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> user = %User{hashed_password: Bcrypt.hash_pwd_salt("strong-pass")}
      iex> User.valid_password?(user, "strong-pass")
      true

  """
  def valid_password?(%__MODULE__{hashed_password: hash}, password)
      when is_binary(hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Returns whether a user has a password hash.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> User.password_set?(%User{hashed_password: "hash"})
      true

  """
  def password_set?(%__MODULE__{hashed_password: hash}), do: is_binary(hash) and hash != ""

  @doc """
  Returns a user with runtime admin status assigned.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> User.with_runtime_role(%User{email: "ADMIN@EXAMPLE.TEST"}).is_admin
      true

  """
  def with_runtime_role(%__MODULE__{} = user) do
    %{user | is_admin: allowed_admin_email?(user.email)}
  end

  def with_runtime_role(nil), do: nil

  @doc """
  Returns whether a user email is whitelisted as admin.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> User.admin?(%User{email: "ADMIN@EXAMPLE.TEST"})
      true

  """
  def admin?(%__MODULE__{is_admin: true}), do: true
  def admin?(%__MODULE__{email: email}), do: allowed_admin_email?(email)
  def admin?(_), do: false

  @doc """
  Returns whether an email is present in the admin whitelist.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> User.allowed_admin_email?("admin@example.test")
      true

  """
  def allowed_admin_email?(email) when is_binary(email) do
    email = normalize_email(email)

    :growthpush_router
    |> Application.get_env(:admin_emails, [])
    |> Enum.map(&normalize_email/1)
    |> Enum.member?(email)
  end

  def allowed_admin_email?(_), do: false

  @doc """
  Normalizes email input for storage and comparison.

  ## Examples

      iex> alias GrowthPushRouter.Accounts.User
      iex> User.normalize_email("  USER@example.COM  ")
      "user@example.com"

  """
  def normalize_email(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
  end

  def normalize_email(other), do: other

  defp maybe_hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> validate_length(:password,
        max: 72,
        count: :bytes,
        message: dgettext("errors", ".password_too_long")
      )
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
