defmodule GrowthPushRouterWeb.UserAuth do
  @moduledoc false

  use GrowthPushRouterWeb, :verified_routes
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  import Phoenix.Controller
  import Plug.Conn

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  def init(action), do: action

  def call(conn, action), do: apply(__MODULE__, action, [conn, []])

  def log_in_user(conn, %User{} = user) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> put_session(:live_socket_id, live_socket_id(user))
    |> redirect(to: user_return_to || signed_in_path(user))
  end

  def log_out_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      GrowthPushRouterWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> put_flash(:info, gettext(".auth.signed_out"))
    |> redirect(to: ~p"/login")
  end

  def fetch_current_user(conn, _opts) do
    user =
      conn
      |> get_session(:user_id)
      |> Accounts.get_user()

    assign(conn, :current_user, user)
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn.assigns.current_user))
      |> halt()
    else
      conn
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, gettext(".auth.authentication_required"))
      |> maybe_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def require_admin_user(conn, _opts) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        if User.admin?(user) do
          conn
        else
          conn
          |> put_flash(:error, gettext(".auth.admin_required"))
          |> redirect(to: ~p"/dashboard")
          |> halt()
        end

      _ ->
        conn
        |> put_flash(:error, gettext(".auth.authentication_required"))
        |> maybe_store_return_to()
        |> redirect(to: ~p"/login")
        |> halt()
    end
  end

  defp signed_in_path(%User{} = user) do
    if User.admin?(user), do: ~p"/admin/users", else: ~p"/dashboard"
  end

  defp live_socket_id(%User{id: id}), do: "users_sessions:#{Base.url_encode64(id)}"

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
