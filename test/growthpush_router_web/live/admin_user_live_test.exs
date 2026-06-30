defmodule GrowthPushRouterWeb.AdminUserLiveTest do
  use GrowthPushRouterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  describe "admin user index live" do
    test "redirects anonymous users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/admin/users")
    end

    test "redirects anonymous users away from all admin user routes", %{conn: conn} do
      {_admin, user} = create_user("anonymous-routes@example.com")

      for path <- [~p"/admin/users", ~p"/admin/users/new", ~p"/admin/users/#{user}/edit"] do
        assert {:error, {:redirect, %{to: "/login"}}} =
                 conn
                 |> recycle()
                 |> live(path)
      end
    end

    test "redirects normal users away from the admin index", %{conn: conn} do
      {_admin, user} = create_user("normal-index@example.com")

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/admin/users")
    end

    test "redirects normal users away from all admin user routes", %{conn: conn} do
      {_admin, user} = create_user("normal-routes@example.com")

      for path <- [~p"/admin/users", ~p"/admin/users/new", ~p"/admin/users/#{user}/edit"] do
        assert {:error, {:redirect, %{to: "/dashboard"}}} =
                 conn
                 |> recycle()
                 |> log_in_user(user)
                 |> live(path)
      end
    end

    test "renders users and confirmation prompts", %{conn: conn} do
      {admin, user} = create_user("client@example.com")

      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users")

      assert html =~ user.email
      assert html =~ "resetar a senha deste usuário?"
      assert html =~ "excluir este usuário?"
    end

    test "resets a user's password", %{conn: conn} do
      {admin, user} = create_user("reset@example.com")

      {:ok, user} =
        Accounts.set_initial_password(user, %{
          "password" => "strong-pass",
          "password_confirmation" => "strong-pass"
        })

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users")

      assert render_click(view, "reset_password", %{"id" => user.id}) =~
               "senha redefinida"

      refute user.id |> Accounts.get_user() |> User.password_set?()
    end

    test "deletes a user", %{conn: conn} do
      {admin, user} = create_user("delete@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users")

      assert render_click(view, "delete", %{"id" => user.id}) =~ "usuário excluído"
      assert Accounts.get_user(user.id) == nil
    end

    test "logout disconnects already connected admin LiveViews", %{conn: conn} do
      admin = create_admin()
      logged_in_conn = log_in_user(conn, admin)

      {:ok, view, _html} = live(logged_in_conn, ~p"/admin/users")

      logged_in_conn
      |> delete(~p"/logout")
      |> redirected_to()

      assert_redirect(view, ~p"/login")
    end
  end

  describe "admin user form live" do
    test "redirects normal users away from admin forms", %{conn: conn} do
      {_admin, user} = create_user("normal-form@example.com")

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/admin/users/new")

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> recycle()
               |> log_in_user(user)
               |> live(~p"/admin/users/#{user}/edit")
    end

    test "renders the new user form", %{conn: conn} do
      admin = create_admin()

      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/new")

      assert html =~ "novo usuário"
      assert html =~ "user[email]"
      assert html =~ "user[name]"
    end

    test "creates a user", %{conn: conn} do
      admin = create_admin()

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/new")

      view
      |> form("#admin-user-form", %{
        "user" => %{
          "email" => "new@example.com",
          "name" => "new user",
          "company" => "new company"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/users")

      assert %User{name: "new user", company: "new company"} =
               Accounts.get_user_by_email("new@example.com")
    end

    test "updates a user", %{conn: conn} do
      {admin, user} = create_user("edit@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      view
      |> form("#admin-user-form", %{
        "user" => %{
          "email" => user.email,
          "name" => "edited user",
          "company" => "edited company"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/users")
      assert %User{name: "edited user", company: "edited company"} = Accounts.get_user(user.id)
    end
  end

  defp create_user(email) do
    admin = create_admin()

    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => email,
        "name" => "client",
        "company" => "client company"
      })

    {admin, user}
  end

  defp create_admin do
    {:ok, admin} =
      Accounts.upsert_seeded_admin(%{
        "email" => "admin@example.test",
        "name" => "admin",
        "company" => "example"
      })

    admin
  end

  defp log_in_user(conn, %User{} = user) do
    Plug.Test.init_test_session(conn, user_id: user.id, live_socket_id: live_socket_id(user))
  end

  defp live_socket_id(%User{id: id}), do: "users_sessions:#{Base.url_encode64(id)}"
end
