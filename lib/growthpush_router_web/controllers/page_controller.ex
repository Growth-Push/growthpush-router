defmodule GrowthPushRouterWeb.PageController do
  use GrowthPushRouterWeb, :controller

  alias GrowthPushRouter.Accounts.User

  def home(conn, _params) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        redirect(conn, to: if(User.admin?(user), do: ~p"/admin/users", else: ~p"/dashboard"))

      _ ->
        redirect(conn, to: ~p"/login")
    end
  end
end
