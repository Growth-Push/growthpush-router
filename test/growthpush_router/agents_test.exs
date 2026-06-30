defmodule GrowthPushRouter.AgentsTest do
  use GrowthPushRouter.DataCase, async: true

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Agent

  doctest GrowthPushRouter.Agents
  doctest GrowthPushRouter.Agents.Agent

  describe "agents" do
    setup do
      Gettext.put_locale(GrowthPushRouterWeb.Gettext, "en")

      admin = %User{email: "admin@example.test"}

      {:ok, owner} =
        Accounts.create_user(admin, %{"email" => "owner@example.com", "name" => "Owner"})

      %{admin: admin, owner: owner}
    end

    test "admin creates an agent owned by a user", %{admin: admin, owner: owner} do
      assert {:ok, %Agent{} = agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert agent.owner_id == owner.id
      assert agent.status == "inactive"
      assert agent.last_errors == %{}
      assert Bcrypt.verify_pass("agent-secret-1234", agent.shared_secret_hash)

      assert agent |> Repo.preload(:owner) |> Map.fetch!(:owner) == owner
    end

    test "admin updates an agent without replacing its secret", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:ok, updated_agent} =
               Agents.update_agent(admin, agent, %{
                 "endpoint_url" => "https://agent.example.test/updated",
                 "status" => "active"
               })

      assert updated_agent.endpoint_url == "https://agent.example.test/updated"
      assert updated_agent.status == "active"
      assert updated_agent.shared_secret_hash == agent.shared_secret_hash
    end

    test "admin replaces an agent secret when one is provided", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:ok, updated_agent} =
               Agents.update_agent(admin, agent, %{"shared_secret" => "replacement-secret"})

      assert updated_agent.shared_secret_hash != agent.shared_secret_hash
      assert Bcrypt.verify_pass("replacement-secret", updated_agent.shared_secret_hash)
    end

    test "validates status", %{admin: admin, owner: owner} do
      assert {:error, changeset} =
               Agents.create_agent(admin, valid_agent_attrs(owner, %{"status" => "paused"}))

      assert "is not a valid agent status" in errors_on(changeset).status
    end

    test "validates slug format", %{admin: admin, owner: owner} do
      assert {:error, changeset} =
               Agents.create_agent(admin, valid_agent_attrs(owner, %{"slug" => "-bad-slug-"}))

      assert "must use lowercase letters, numbers, and hyphens" in errors_on(changeset).slug
    end

    test "enforces globally unique slugs", %{admin: admin, owner: owner} do
      assert {:ok, _agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:error, changeset} = Agents.create_agent(admin, valid_agent_attrs(owner))
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "validates endpoint url", %{admin: admin, owner: owner} do
      assert {:error, changeset} =
               Agents.create_agent(
                 admin,
                 valid_agent_attrs(owner, %{"endpoint_url" => "ftp://agent"})
               )

      assert "must be an http or https URL" in errors_on(changeset).endpoint_url
    end

    test "requires an existing owner", %{admin: admin, owner: owner} do
      missing_owner_id = Ecto.UUID.generate()

      assert {:error, changeset} =
               Agents.create_agent(
                 admin,
                 valid_agent_attrs(owner, %{"owner_id" => missing_owner_id})
               )

      assert "does not exist" in errors_on(changeset).owner_id
    end

    test "requires a shared secret for new agents", %{admin: admin, owner: owner} do
      assert {:error, changeset} =
               Agents.create_agent(admin, valid_agent_attrs(owner, %{"shared_secret" => nil}))

      assert "can't be blank" in errors_on(changeset).shared_secret
    end

    test "rejects short shared secrets", %{admin: admin, owner: owner} do
      assert {:error, changeset} =
               Agents.create_agent(admin, valid_agent_attrs(owner, %{"shared_secret" => "short"}))

      assert "must be at least 16 characters" in errors_on(changeset).shared_secret
    end

    test "create, update, delete, and list reject non-admin users", %{admin: admin, owner: owner} do
      non_admin = %User{email: "client@example.com"}
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:error, :unauthorized} = Agents.create_agent(non_admin, valid_agent_attrs(owner))

      assert {:error, :unauthorized} =
               Agents.update_agent(non_admin, agent, %{"status" => "active"})

      assert {:error, :unauthorized} = Agents.delete_agent(non_admin, agent)
      assert {:error, :unauthorized} = Agents.list_agents(non_admin)
    end

    test "admin can list agents", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:ok, [^agent]} = Agents.list_agents(admin, owner_id: owner.id)
      assert {:ok, [^agent]} = Agents.list_agents(admin, status: "inactive")
      assert {:ok, [^agent]} = Agents.list_agents(admin, slug: agent.slug)
    end

    test "admin and owner can fetch an agent", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:ok, ^agent} = Agents.fetch_agent(admin, agent.id)
      assert {:ok, ^agent} = Agents.fetch_agent(owner, agent.id)
    end

    test "unrelated users cannot fetch an agent", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      {:ok, other_user} =
        Accounts.create_user(admin, %{"email" => "other@example.com", "name" => "Other"})

      assert {:error, :unauthorized} = Agents.fetch_agent(other_user, agent.id)
    end

    test "admin deletes an agent", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:ok, deleted_agent} = Agents.delete_agent(admin, agent)
      assert_raise Ecto.NoResultsError, fn -> Agents.fetch_agent(admin, deleted_agent.id) end
    end
  end

  defp valid_agent_attrs(%User{} = owner, attrs \\ %{}) do
    Map.merge(
      %{
        "owner_id" => owner.id,
        "slug" => "client-agent",
        "endpoint_url" => "https://agent.example.test/events",
        "shared_secret" => "agent-secret-1234"
      },
      attrs
    )
  end
end
