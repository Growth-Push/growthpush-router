defmodule GrowthPushRouterWeb.PasswordSetupController do
  use GrowthPushRouterWeb, :controller

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouterWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email} = user_params}) do
    password_params = Map.take(user_params, ["password", "password_confirmation"])

    case Accounts.set_initial_password(email, password_params) do
      {:ok, %User{} = user} ->
        conn
        |> put_flash(:info, gettext(".password_setup.password_set"))
        |> UserAuth.log_in_user(user)

      {:error, :password_already_set} ->
        conn
        |> put_flash(:error, gettext(".password_setup.password_already_set"))
        |> redirect(to: ~p"/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, password_error(changeset))
        |> redirect(to: ~p"/password/setup?email=#{email_for_redirect(email)}")

      :error ->
        conn
        |> put_flash(:error, gettext(".password_setup.unknown_email"))
        |> redirect(to: ~p"/password/setup?email=#{email_for_redirect(email)}")
    end
  end

  defp password_error(%Ecto.Changeset{}), do: gettext(".password_setup.invalid_password")

  defp email_for_redirect(email) when is_binary(email), do: String.slice(email, 0, 160)
  defp email_for_redirect(_email), do: ""
end
