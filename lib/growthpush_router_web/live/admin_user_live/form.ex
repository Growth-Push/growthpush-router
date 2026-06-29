defmodule GrowthPushRouterWeb.AdminUserLive.Form do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    with %User{} = user <- Accounts.get_user(session["user_id"]),
         true <- User.admin?(user) do
      subscribe_to_live_socket(socket, session)

      {:ok, assign(socket, current_user: user, user: nil, form: nil)}
    else
      _ -> {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)
      |> Phoenix.Component.to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.live_action, user_params)
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "disconnect"}, socket) do
    {:noreply, redirect(socket, to: ~p"/login")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200">
      <GrowthPushRouterWeb.AdminUserLive.Index.admin_nav current_user={@current_user} />

      <section class="mx-auto w-full max-w-2xl px-4 py-8">
        <div class="rounded-lg bg-base-100 p-6 shadow-sm">
          <h1 class="mb-6 text-2xl font-semibold">{@page_title}</h1>
          <.form
            id="admin-user-form"
            for={@form}
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:email]}
              type="email"
              label={gettext(".admin_user_form.email")}
              required
            />
            <.input
              field={@form[:name]}
              type="text"
              label={gettext(".admin_user_form.name")}
              required
            />
            <.input field={@form[:company]} type="text" label={gettext(".admin_user_form.company")} />

            <div class="flex justify-end gap-2">
              <.link navigate={~p"/admin/users"} class="btn">{gettext(".admin_user_form.cancel")}</.link>
              <.button class="btn btn-primary">{gettext(".admin_user_form.save")}</.button>
            </div>
          </.form>
        </div>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp apply_action(socket, :new, _params) do
    user = %User{}

    socket
    |> assign(:page_title, gettext(".admin_users.new_title"))
    |> assign(:user, user)
    |> assign_form(Accounts.change_user(user))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Accounts.fetch_user(socket.assigns.current_user, id) do
      {:ok, user} ->
        socket
        |> assign(:page_title, gettext(".admin_users.edit_title"))
        |> assign(:user, user)
        |> assign_form(Accounts.change_user(user))

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext(".auth.admin_required"))
        |> redirect(to: ~p"/dashboard")
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.create_user(socket.assigns.current_user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_users.user_created"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.current_user, socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_users.user_updated"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, Phoenix.Component.to_form(changeset))
  end

  defp subscribe_to_live_socket(socket, %{"live_socket_id" => live_socket_id})
       when is_binary(live_socket_id) do
    if connected?(socket) do
      GrowthPushRouterWeb.Endpoint.subscribe(live_socket_id)
    end
  end

  defp subscribe_to_live_socket(_socket, _session), do: :ok
end
