defmodule GrowthPushRouterWeb.AdminUserLive.Index do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    with %User{} = user <- Accounts.get_user(session["user_id"]),
         true <- User.admin?(user) do
      subscribe_to_live_socket(socket, session)

      {:ok, assign(socket, current_user: user, q: "", users: [])}
    else
      _ -> {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    search = params["q"] || ""

    case Accounts.list_users(socket.assigns.current_user, search: search) do
      {:ok, users} ->
        {:noreply, assign(socket, q: search, users: users)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext(".auth.admin_required"))
         |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Accounts.fetch_user(socket.assigns.current_user, id) do
      {:ok, %User{id: current_user_id}} when current_user_id == socket.assigns.current_user.id ->
        {:noreply, put_flash(socket, :error, gettext(".admin_users.cannot_delete_self"))}

      {:ok, user} ->
        delete_user(socket, user)

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}
    end
  end

  def handle_event("reset_password", %{"id" => id}, socket) do
    case Accounts.fetch_user(socket.assigns.current_user, id) do
      {:ok, user} ->
        reset_user_password(socket, user)

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "disconnect"}, socket) do
    {:noreply, redirect(socket, to: ~p"/login")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200">
      <.admin_nav current_user={@current_user} />

      <section class="mx-auto w-full max-w-6xl px-4 py-8">
        <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-sm font-medium text-primary">{gettext(".admin_users.section")}</p>
            <h1 class="text-2xl font-semibold">{gettext(".admin_users.title")}</h1>
          </div>

          <.link navigate={~p"/admin/users/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="size-4" /> {gettext(".admin_users.new_user")}
          </.link>
        </div>

        <.form for={%{}} as={:search} action={~p"/admin/users"} method="get" class="mb-4 flex gap-2">
          <input
            class="input w-full"
            type="search"
            name="q"
            value={@q}
            placeholder={gettext(".admin_users.search_placeholder")}
          />
          <button class="btn" type="submit">
            <.icon name="hero-magnifying-glass" class="size-4" />
          </button>
        </.form>

        <div class="overflow-x-auto rounded-lg bg-base-100 shadow-sm">
          <table class="table">
            <thead>
              <tr>
                <th>{gettext(".admin_users.email")}</th>
                <th>{gettext(".admin_users.name")}</th>
                <th>{gettext(".admin_users.company")}</th>
                <th>{gettext(".admin_users.kind")}</th>
                <th>{gettext(".admin_users.password")}</th>
                <th class="text-right">{gettext(".admin_users.actions")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={user <- @users}>
                <td class="font-medium">{user.email}</td>
                <td>{user.name}</td>
                <td>{user.company || "-"}</td>
                <td>
                  <span class={["badge px-2", User.admin?(user) && "badge-primary"]}>
                    {if User.admin?(user),
                      do: gettext(".admin_users.admin"),
                      else: gettext(".admin_users.regular_user")}
                  </span>
                </td>
                <td>
                  <span class={[
                    "badge px-2",
                    User.password_set?(user) && "badge-success",
                    !User.password_set?(user) && "badge-warning"
                  ]}>
                    {if User.password_set?(user),
                      do: gettext(".admin_users.password_set"),
                      else: gettext(".admin_users.password_pending")}
                  </span>
                </td>
                <td>
                  <div class="flex justify-end gap-2">
                    <.link navigate={~p"/admin/users/#{user}/edit"} class="btn btn-sm">
                      <.icon name="hero-pencil-square" class="size-4" />
                    </.link>
                    <button
                      class="btn btn-sm"
                      type="button"
                      data-confirm={gettext(".admin_users.reset_password_confirm")}
                      phx-click={JS.push("reset_password", value: %{id: user.id})}
                    >
                      <.icon name="hero-key" class="size-4" />
                    </button>
                    <button
                      class="btn btn-sm btn-error"
                      type="button"
                      disabled={user.id == @current_user.id}
                      data-confirm={gettext(".admin_users.delete_confirm")}
                      phx-click={JS.push("delete", value: %{id: user.id})}
                    >
                      <.icon name="hero-trash" class="size-4" />
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  attr :current_user, User, required: true

  def admin_nav(assigns) do
    ~H"""
    <header class="border-b border-base-300 bg-base-100">
      <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <nav class="flex items-center gap-3">
          <.link navigate={~p"/admin/users"} class="font-semibold">
            {gettext(".admin_nav.title")}
          </.link>
          <.link navigate={~p"/admin/events"} class="btn btn-sm btn-primary btn-soft">
            <.icon name="hero-inbox-stack" class="size-4" />
            {gettext(".admin_nav.events")}
          </.link>
        </nav>
        <div class="flex items-center gap-3">
          <span class="hidden text-sm text-base-content/70 sm:block">{@current_user.email}</span>
          <.link href={~p"/logout"} method="delete" class="btn btn-sm">
            <.icon name="hero-arrow-left-on-rectangle" class="size-4" />
            {gettext(".admin_nav.sign_out")}
          </.link>
        </div>
      </div>
    </header>
    """
  end

  defp delete_user(socket, %User{} = user) do
    case Accounts.delete_user(socket.assigns.current_user, user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_users.user_deleted"))
         |> reload_users()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}
    end
  end

  defp reset_user_password(socket, %User{} = user) do
    case Accounts.reset_user_password(socket.assigns.current_user, user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_users.password_reset"))
         |> reload_users()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext(".admin_users.password_reset_failed"))}
    end
  end

  defp reload_users(socket) do
    case Accounts.list_users(socket.assigns.current_user, search: socket.assigns.q) do
      {:ok, users} -> assign(socket, :users, users)
      {:error, :unauthorized} -> socket
    end
  end

  defp subscribe_to_live_socket(socket, %{"live_socket_id" => live_socket_id})
       when is_binary(live_socket_id) do
    if connected?(socket) do
      GrowthPushRouterWeb.Endpoint.subscribe(live_socket_id)
    end
  end

  defp subscribe_to_live_socket(_socket, _session), do: :ok
end
