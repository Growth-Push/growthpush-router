defmodule GrowthPushRouterWeb.SessionController do
  use GrowthPushRouterWeb, :controller

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouterWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      {:error, :password_not_set, user} ->
        conn
        |> put_flash(:info, gettext(".session.password_setup_required"))
        |> redirect(to: ~p"/password/setup?email=#{user.email}")

      :error ->
        conn
        |> put_flash(:error, gettext(".session.invalid_credentials"))
        |> redirect(to: ~p"/login?email=#{email_for_redirect(email)}")
    end
  end

  def delete(conn, _params), do: UserAuth.log_out_user(conn)

  defp email_for_redirect(email) when is_binary(email), do: String.slice(email, 0, 160)
  defp email_for_redirect(_email), do: ""
end
