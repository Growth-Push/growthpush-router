defmodule GrowthPushRouterWeb.AdminUserLiveTest do
  use GrowthPushRouterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents

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
      refute html =~ "admin-agent-form"
    end

    test "renders the agent section on the edit user form", %{conn: conn} do
      {admin, user} = create_user("agent-section@example.com")

      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      assert html =~ "admin-agent-form"
      assert html =~ "criar agent"
      assert html =~ "agent[slug]"
      assert html =~ "agent[endpoint_url]"
      assert html =~ "agent[shared_secret]"
      assert html =~ "phx-hook=\"ClipboardCopy\""
      assert html =~ "copiar"
      assert html =~ "ver"
      assert html =~ "client-company-agent"
      assert html =~ "O teste envia um GET"
      assert html =~ "O segredo é armazenado apenas como hash"
      assert html =~ "GROWTHPUSH_AGENT_SHARED_SECRET"
      assert endpoint_test_button_disabled?(html)
    end

    test "suggests agent slug from the user company", %{conn: conn} do
      {admin, user} = create_user("entre-mundos@example.com", "Entre Mundos")

      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      assert html =~ "entre-mundos-agent"
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

    test "creates an agent for the edited user", %{conn: conn} do
      {admin, user} = create_user("create-agent@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      view
      |> form("#admin-agent-form", %{
        "agent" => valid_agent_form_params("created-agent")
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/users")

      assert {:ok, [agent]} = Agents.list_agents(admin, owner_id: user.id)
      assert agent.slug == "created-agent"
      assert agent.status == "inactive"
      assert Bcrypt.verify_pass("agent-secret-1234", agent.shared_secret_hash)
    end

    test "generates an agent secret without saving the agent", %{conn: conn} do
      {admin, user} = create_user("generate-agent-secret@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      html = render_click(view, "generate_agent_secret")

      generated_secret =
        html
        |> Floki.parse_document!()
        |> Floki.find("input[name='agent[shared_secret]']")
        |> Floki.attribute("value")
        |> List.first()

      assert is_binary(generated_secret)
      assert String.length(generated_secret) >= 32
      assert {:ok, []} = Agents.list_agents(admin, owner_id: user.id)
    end

    test "toggles generated agent secret visibility", %{conn: conn} do
      {admin, user} = create_user("show-agent-secret@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      html = render_click(view, "generate_agent_secret")
      assert secret_input_type(html) == "password"

      html = render_click(view, "toggle_agent_secret_visibility")
      assert html =~ "ocultar"
      assert secret_input_type(html) == "text"

      html = render_click(view, "toggle_agent_secret_visibility")
      assert html =~ "ver"
      assert secret_input_type(html) == "password"
    end

    test "updates an existing agent without requiring a new secret", %{conn: conn} do
      {admin, user} = create_user("update-agent@example.com")
      {:ok, agent} = create_agent(admin, user, "updated-agent")

      {:ok, view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      refute endpoint_test_button_disabled?(html)

      view
      |> form("#admin-agent-form", %{
        "agent" => %{
          "slug" => agent.slug,
          "endpoint_url" => "https://agent.example.test/updated",
          "status" => "active",
          "shared_secret" => ""
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/users")

      assert {:ok, [updated_agent]} = Agents.list_agents(admin, owner_id: user.id)
      assert updated_agent.endpoint_url == "https://agent.example.test/updated"
      assert updated_agent.status == "active"
      assert updated_agent.shared_secret_hash == agent.shared_secret_hash
    end

    test "tests an agent endpoint healthcheck successfully", %{conn: conn} do
      {admin, user} = create_user("test-agent-endpoint@example.com")

      Req.Test.stub(GrowthPushRouter.AgentHealthcheck, fn conn ->
        Req.Test.text(conn, "ok")
      end)

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      Req.Test.allow(GrowthPushRouter.AgentHealthcheck, self(), view.pid)

      html =
        render_click(view, "test_agent_endpoint", %{
          "endpoint_url" => "https://agent.example.test/health"
        })

      assert html =~ "healthcheck respondeu com 200"
    end

    test "reports failed endpoint healthchecks", %{conn: conn} do
      {admin, user} = create_user("test-agent-endpoint-failed@example.com")

      Req.Test.stub(GrowthPushRouter.AgentHealthcheck, fn conn ->
        Plug.Conn.send_resp(conn, 503, "unavailable")
      end)

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      Req.Test.allow(GrowthPushRouter.AgentHealthcheck, self(), view.pid)

      html =
        render_click(view, "test_agent_endpoint", %{
          "endpoint_url" => "https://agent.example.test/health"
        })

      assert html =~ "healthcheck respondeu com 503"
    end

    test "reports invalid endpoint healthcheck URLs without crashing", %{conn: conn} do
      {admin, user} = create_user("test-agent-invalid-endpoint@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      for endpoint_url <- ["foo", "ftp://agent", "http://"] do
        html = render_click(view, "test_agent_endpoint", %{"endpoint_url" => endpoint_url})
        assert html =~ "healthcheck não respondeu"
      end
    end

    test "replaces an existing agent secret when provided", %{conn: conn} do
      {admin, user} = create_user("replace-agent-secret@example.com")
      {:ok, agent} = create_agent(admin, user, "replace-agent-secret")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      view
      |> form("#admin-agent-form", %{
        "agent" => %{
          "slug" => agent.slug,
          "endpoint_url" => agent.endpoint_url,
          "status" => "inactive",
          "shared_secret" => "replacement-secret"
        }
      })
      |> render_submit()

      assert {:ok, [updated_agent]} = Agents.list_agents(admin, owner_id: user.id)
      assert updated_agent.shared_secret_hash != agent.shared_secret_hash
      assert Bcrypt.verify_pass("replacement-secret", updated_agent.shared_secret_hash)
    end

    test "renders translated agent validation errors", %{conn: conn} do
      {_admin, user} = create_user("agent-errors@example.com")

      {:ok, view, _html} =
        conn
        |> log_in_user(create_admin())
        |> live(~p"/admin/users/#{user}/edit")

      html =
        view
        |> form("#admin-agent-form", %{
          "agent" => %{
            "slug" => "-bad-",
            "endpoint_url" => "ftp://agent",
            "status" => "inactive",
            "shared_secret" => "short"
          }
        })
        |> render_submit()

      assert html =~ "deve usar letras minúsculas"
      assert html =~ "deve ser uma URL http ou https"
      assert html =~ "deve ter pelo menos 16 caracteres"
    end

    test "deletes an agent only after exact slug confirmation", %{conn: conn} do
      {admin, user} = create_user("delete-agent@example.com")
      {:ok, agent} = create_agent(admin, user, "delete-agent")

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/users/#{user}/edit")

      html = render_click(view, "request_delete_agent")
      assert html =~ "delete-agent-modal"
      assert html =~ agent.slug

      view
      |> form("#delete-agent-modal form", %{"agent_delete" => %{"confirmation" => "wrong"}})
      |> render_submit()

      assert {:ok, [_agent]} = Agents.list_agents(admin, owner_id: user.id)

      html =
        view
        |> form("#delete-agent-modal form", %{
          "agent_delete" => %{"confirmation" => agent.slug}
        })
        |> render_submit()

      assert html =~ "agent excluído"
      assert {:ok, []} = Agents.list_agents(admin, owner_id: user.id)
      assert html =~ "admin-agent-form"
    end
  end

  defp create_user(email, company \\ "client company") do
    admin = create_admin()

    {:ok, user} =
      Accounts.create_user(admin, %{
        "email" => email,
        "name" => "client",
        "company" => company
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

  defp create_agent(%User{} = admin, %User{} = owner, slug) do
    Agents.create_agent(admin, valid_agent_params(owner, slug))
  end

  defp valid_agent_form_params(slug) do
    %{
      "slug" => slug,
      "endpoint_url" => "https://agent.example.test/events",
      "status" => "inactive",
      "shared_secret" => "agent-secret-1234"
    }
  end

  defp valid_agent_params(%User{} = owner, slug) do
    owner
    |> Map.fetch!(:id)
    |> then(&Map.put(valid_agent_form_params(slug), "owner_id", &1))
  end

  defp endpoint_test_button_disabled?(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("button[phx-click='test_agent_endpoint']")
    |> List.first()
    |> button_disabled?()
  end

  defp button_disabled?({_tag, attrs, _children}) do
    Enum.any?(attrs, fn {name, _value} -> name == "disabled" end)
  end

  defp secret_input_type(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("input[name='agent[shared_secret]']")
    |> Floki.attribute("type")
    |> List.first()
  end
end
