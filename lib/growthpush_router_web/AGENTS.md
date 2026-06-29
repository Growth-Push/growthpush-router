# AGENTS.md

## Gettext And User-Facing Text

- No user-facing text may be hardcoded in templates, controllers, flashes, labels, placeholders, buttons, tables, or navigation.
- Use scoped Gettext keys:

  ```elixir
  gettext(".session.title")
  gettext(".admin_users.user_created")
  gettext(".dashboard.title", name: user.name)
  ```

- Avoid generic repeated keys such as `gettext(".title")` when they can collide across screens. Prefer area prefixes:
  - `.session.*`
  - `.password_setup.*`
  - `.admin_users.*`
  - `.admin_user_form.*`
  - `.admin_nav.*`
  - `.dashboard.*`
  - `.auth.*`
- After adding or changing text, run:

  ```bash
  mix gettext.extract --merge --no-fuzzy
  ```

- Fill in `msgstr` values in `priv/gettext/pt/LC_MESSAGES/default.po` and `priv/gettext/en/LC_MESSAGES/default.po`. Do not leave new keys empty in `.po` files.
- The `.pot` file has empty `msgstr ""` entries by design; do not use it to validate final translations.
- Useful validation:

  ```bash
  rg -n 'msgid "\\.[^"]+"\\nmsgstr ""' -U priv/gettext/*/LC_MESSAGES/*.po
  ```

  It should not return results for new keys.

## LiveView, Controllers, And Authorization

- Web routes and plugs may restrict access, but domain authorization still belongs in contexts.
- UI screens should be implemented as LiveViews by default.
- Controllers are acceptable for auth/session POST/DELETE actions and simple redirects. They should not render HTML screens unless there is an explicit reason.
- Admin user LiveViews must pass the acting current user into context functions for list, read, create, update, delete, and password reset operations.
- Handle `{:error, :unauthorized}` explicitly even when the route is already protected.
- Do not implement admin authorization directly in templates.

## Public Web Helpers

- Public helper/component functions that are not controller actions must have `@doc`.
- Each public helper/component doc must include at least one executable doctest covering the happy path when the function is pure enough to doctest.
- If a public helper/component cannot reasonably have a doctest, document why in the function `@doc` and cover the happy path with a regular test.

## Current Auth Routes

- `/login`: sign in.
- `/password/setup`: first access or reset account.
- `/logout`: sign out.
- `/admin/users`: admin user CRUD LiveView.
- `/dashboard`: simple dashboard LiveView for normal users.
- `/`: redirects by session: admin to `/admin/users`, normal user to `/dashboard`, anonymous user to `/login`.
