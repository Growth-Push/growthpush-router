# AGENTS.md

## Domain Contexts

- Every public context function must have `@doc`.
- Each public context function doc must include at least one executable doctest covering the happy path.
- If a context function cannot reasonably have a doctest, document why in the function `@doc` and cover the happy path with a regular test.
- Context modules should use a consistent `filter_query/2` style when accepting filters.
- Public list functions should start from a base query, reduce over opts, and delegate each supported filter to `filter_query/2`:

  ```elixir
  def list_users(admin_user, opts \\ []) do
    with :ok <- authorize_admin(admin_user) do
      {:ok, do_list_users(opts)}
    end
  end

  defp do_list_users(opts) do
    query = from(u in User)

    opts
    |> Enum.reduce(query, fn filter, q ->
      filter_query(q, [filter])
    end)
    |> Repo.all()
  end

  defp filter_query(query, email: email), do: where(query, [u], u.email == ^email)
  defp filter_query(query, _), do: query
  ```

- Prefer adding new filter clauses over embedding ad hoc conditionals in public context functions.
- Keep the fallback `defp filter_query(query, _), do: query` so unknown options are ignored consistently.
- Prefer pipelines over nested helper calls when transforming data for the next helper; write `opts |> force_owner_filter(owner_id) |> do_list_agents()` instead of `do_list_agents(force_owner_filter(opts, owner_id))`.
- Prefer happy-path function clauses and small private helpers over large `cond` blocks. Use `cond` only when the alternatives are genuinely symmetric and clauses would be less clear.

## Admin-Gated User Operations

- User CRUD and admin password reset are business operations and must be authorized inside `GrowthPushRouter.Accounts`, not only by web routes or controllers.
- Public context functions that list, read, create, update, delete, or reset users for admin workflows must receive the acting admin user as their first argument:

  ```elixir
  Accounts.list_users(admin_user, opts)
  Accounts.fetch_user(admin_user, id)
  Accounts.create_user(admin_user, attrs)
  Accounts.update_user(admin_user, user, attrs)
  Accounts.delete_user(admin_user, user)
  Accounts.reset_user_password(admin_user, user)
  ```

- Unauthorized actors must return `{:error, :unauthorized}`.
- `GrowthPushRouter.Accounts.User.admin?/1` is the canonical admin predicate.
- Admin status is derived from the `GROWTHPUSH_ADMIN_EMAILS` env var loaded at runtime; do not hardcode admin emails in shared config or add database roles unless explicitly requested.
- Bootstrap-only seed helpers may bypass admin actor checks, but keep them clearly named for seeding/bootstrap, not general CRUD.

## Auth Business Rules

- Keep auth intentionally small. Do not add MFA, Google SSO, email recovery, email confirmation, database encryption, or public registration flows unless explicitly requested.
- The app does not send emails.
- There is no self-service password recovery. If a user cannot sign in, they must contact an admin.
- Normal users cannot self-register. Users are created by admins.
- A new user is created without a password. If `hashed_password` is empty, the user can define their password at `/password/setup`.
- Admin password reset does not create a token and does not send email: it clears `hashed_password`, and the user defines a new password on the next access.
- Initial admins are created by `GrowthPushRouter.Seeds` from `GROWTHPUSH_ADMIN_EMAILS`. `priv/repo/seeds.exs` should only call the backend seed module. Do not hardcode seed admin data in config or source files.

## Schemas And Validations

- Every public schema function must have `@doc`.
- Each public schema function doc must include at least one executable doctest covering the happy path.
- If a schema function cannot reasonably have a doctest, document why in the function `@doc` and cover the happy path with a regular test.
- Schemas should use `@required` and `@optional` field lists near the schema.
- Cast with `@required ++ @optional`.
- Validate required fields with `validate_required(@required, ...)`.
- All validation messages must use the `errors` Gettext domain via `dgettext("errors", ...)`.
- Do not leave validation messages as raw English strings or Ecto defaults when adding new validations.
- Example:

  ```elixir
  @optional ~w(company)a
  @required ~w(email name)a

  def changeset(user, attrs) do
    user
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required, message: dgettext("errors", ".cant_be_blank"))
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: dgettext("errors", ".wrong_email"))
  end
  ```

- After changing schema validation messages, run:

  ```bash
  mix gettext.extract --merge --no-fuzzy
  ```

- Complete translations in `priv/gettext/*/LC_MESSAGES/errors.po`.
