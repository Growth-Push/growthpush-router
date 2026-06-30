defmodule GrowthPushRouterWeb.DashboardLive.Index do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    case Accounts.get_user(session["user_id"]) do
      %User{} = user ->
        if User.admin?(user) do
          {:ok, redirect(socket, to: ~p"/admin/users")}
        else
          subscribe_to_live_socket(socket, session)

          {:ok, assign(socket, :current_user, user)}
        end

      _ ->
        {:ok, redirect(socket, to: ~p"/login")}
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
      <header class="border-b border-base-300 bg-base-100">
        <div class="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
          <span class="font-semibold">{gettext(".dashboard.nav_title")}</span>
          <.link href={~p"/logout"} method="delete" class="btn btn-sm">
            <.icon name="hero-arrow-left-on-rectangle" class="size-4" />
            {gettext(".dashboard.sign_out")}
          </.link>
        </div>
      </header>

      <section class="mx-auto w-full max-w-5xl px-4 py-8">
        <div class="rounded-lg bg-base-100 p-6 shadow-sm">
          <p class="text-sm font-medium text-primary">{gettext(".dashboard.section")}</p>
          <h1 class="mt-1 text-2xl font-semibold">
            {gettext(".dashboard.title", name: @current_user.name)}
          </h1>
          <p class="mt-2 text-base-content/70">
            {gettext(".dashboard.subtitle")}
          </p>

          <dl class="mt-6 grid gap-4 sm:grid-cols-3">
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".dashboard.email")}</dt>
              <dd class="mt-1 font-medium">{@current_user.email}</dd>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".dashboard.company")}</dt>
              <dd class="mt-1 font-medium">{@current_user.company || "-"}</dd>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".dashboard.access")}</dt>
              <dd class="mt-1 font-medium">{gettext(".dashboard.regular_user")}</dd>
            </div>
          </dl>
        </div>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp subscribe_to_live_socket(socket, %{"live_socket_id" => live_socket_id})
       when is_binary(live_socket_id) do
    if connected?(socket) do
      GrowthPushRouterWeb.Endpoint.subscribe(live_socket_id)
    end
  end

  defp subscribe_to_live_socket(_socket, _session), do: :ok
end
