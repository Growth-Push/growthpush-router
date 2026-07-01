defmodule GrowthPushRouter.AgentsTest do
  use GrowthPushRouter.DataCase, async: true

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Agent
  alias GrowthPushRouter.Agents.Connection
  alias GrowthPushRouter.Agents.Event

  doctest GrowthPushRouter.Agents
  doctest GrowthPushRouter.Agents.Agent
  doctest GrowthPushRouter.Agents.Connection
  doctest GrowthPushRouter.Agents.Event

  describe "agents" do
    setup do
      Gettext.put_locale(GrowthPushRouterWeb.Gettext, "en")

      admin = User.with_runtime_role(%User{email: "admin@example.test"})

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

    test "admin can list agents with filters", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:ok, [^agent]} = Agents.list_agents(admin, owner_id: owner.id)
      assert {:ok, [^agent]} = Agents.list_agents(admin, status: "inactive")
      assert {:ok, [^agent]} = Agents.list_agents(admin, slug: agent.slug)
    end

    test "users can list only agents they own", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      {:ok, other_user} =
        Accounts.create_user(admin, %{"email" => "other-owner@example.com", "name" => "Other"})

      {:ok, _other_agent} =
        Agents.create_agent(admin, valid_agent_attrs(other_user, %{"slug" => "other-agent"}))

      assert {:ok, [^agent]} = Agents.list_agents(owner)
      assert {:ok, [^agent]} = Agents.list_agents(owner, owner_id: other_user.id)
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

    test "owner fetch uses scoped filters instead of raising on missing agents", %{owner: owner} do
      assert {:error, :unauthorized} = Agents.fetch_agent(owner, Ecto.UUID.generate())
      assert {:error, :unauthorized} = Agents.fetch_agent(owner, "not-a-uuid")
    end

    test "admin deletes an agent", %{admin: admin, owner: owner} do
      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      assert {:ok, deleted_agent} = Agents.delete_agent(admin, agent)
      assert_raise Ecto.NoResultsError, fn -> Agents.fetch_agent(admin, deleted_agent.id) end
    end
  end

  describe "connections" do
    setup do
      Gettext.put_locale(GrowthPushRouterWeb.Gettext, "en")

      admin = User.with_runtime_role(%User{email: "admin@example.test"})

      {:ok, owner} =
        Accounts.create_user(admin, %{
          "email" => "connection-owner@example.com",
          "name" => "Owner"
        })

      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))

      %{admin: admin, owner: owner, agent: agent}
    end

    test "admin creates a Meta Instagram connection for an agent", %{
      admin: admin,
      owner: owner,
      agent: agent
    } do
      last_connected_at = DateTime.utc_now(:second)

      assert {:ok, %Connection{} = connection} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(agent, owner, %{
                   "last_connected_at" => last_connected_at,
                   "last_checked_at" => last_connected_at,
                   "last_error_at" => last_connected_at,
                   "last_errors" => %{"code" => "rate_limited"}
                 })
               )

      assert connection.agent_id == agent.id
      assert connection.connected_by_user_id == owner.id
      assert connection.provider == "meta"
      assert connection.channel == "instagram"
      assert connection.status == "active"
      assert connection.scopes == []
      assert connection.access_token_ref == "vault://meta/instagram/growth-push"
      assert connection.last_connected_at == last_connected_at
      assert connection.last_checked_at == last_connected_at
      assert connection.last_error_at == last_connected_at
      assert connection.last_errors == %{"code" => "rate_limited"}

      preloaded_connection = Repo.preload(connection, [:agent, :connected_by_user])

      assert preloaded_connection.agent == agent
      assert preloaded_connection.connected_by_user == owner
    end

    test "defaults operational fields", %{admin: admin, owner: owner, agent: agent} do
      assert {:ok, connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      assert connection.status == "active"
      assert connection.scopes == []
      assert connection.last_connected_at == nil
      assert connection.last_checked_at == nil
      assert connection.last_error_at == nil
      assert connection.last_errors == %{}
    end

    test "validates provider channel and status", %{admin: admin, owner: owner, agent: agent} do
      assert {:error, changeset} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(agent, owner, %{"provider" => "google"})
               )

      assert "is not a supported connection provider" in errors_on(changeset).provider

      assert {:error, changeset} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(agent, owner, %{"channel" => "facebook"})
               )

      assert "is not a supported connection channel" in errors_on(changeset).channel

      assert {:error, changeset} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(agent, owner, %{"status" => "pending"})
               )

      assert "is not a valid connection status" in errors_on(changeset).status
    end

    test "requires access token ref instead of a raw token", %{
      admin: admin,
      owner: owner,
      agent: agent
    } do
      assert {:error, changeset} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(agent, owner, %{
                   "access_token_ref" => "EAAGraw-provider-token"
                 })
               )

      assert "must be a token reference, not a raw token" in errors_on(changeset).access_token_ref
    end

    test "requires existing agent and connected by user", %{
      admin: admin,
      owner: owner,
      agent: agent
    } do
      missing_agent_id = Ecto.UUID.generate()
      missing_user_id = Ecto.UUID.generate()

      assert {:error, changeset} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(agent, owner, %{"agent_id" => missing_agent_id})
               )

      assert "does not exist" in errors_on(changeset).agent_id

      assert {:error, changeset} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(agent, owner, %{
                   "connected_by_user_id" => missing_user_id
                 })
               )

      assert "does not exist" in errors_on(changeset).connected_by_user_id
    end

    test "enforces unique external account per provider and channel", %{
      admin: admin,
      owner: owner,
      agent: agent
    } do
      assert {:ok, _connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      assert {:error, changeset} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      assert "has already been taken" in errors_on(changeset).external_account_id
    end

    test "admin can list connections with filters", %{admin: admin, owner: owner, agent: agent} do
      assert {:ok, connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      assert {:ok, [^connection]} = Agents.list_connections(admin, agent_id: agent.id)

      assert {:ok, [^connection]} =
               Agents.list_connections(admin, connected_by_user_id: owner.id)

      assert {:ok, [^connection]} = Agents.list_connections(admin, provider: "Meta")
      assert {:ok, [^connection]} = Agents.list_connections(admin, channel: "Instagram")
      assert {:ok, [^connection]} = Agents.list_connections(admin, status: "Active")
    end

    test "admin and owner can fetch a connection", %{admin: admin, owner: owner, agent: agent} do
      assert {:ok, connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      assert {:ok, ^connection} = Agents.fetch_connection(admin, connection.id)
      assert {:ok, ^connection} = Agents.fetch_connection(owner, connection.id)
    end

    test "users can list only connections for agents they own", %{
      admin: admin,
      owner: owner,
      agent: agent
    } do
      {:ok, other_owner} =
        Accounts.create_user(admin, %{
          "email" => "other-connection-owner@example.com",
          "name" => "Other Owner"
        })

      {:ok, other_agent} =
        Agents.create_agent(
          admin,
          valid_agent_attrs(other_owner, %{"slug" => "other-client-agent"})
        )

      assert {:ok, connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      assert {:ok, _other_connection} =
               Agents.create_connection(
                 admin,
                 valid_connection_attrs(other_agent, other_owner, %{
                   "external_account_id" => "other-growth-push-account"
                 })
               )

      assert {:ok, [^connection]} = Agents.list_connections(owner)
      assert {:ok, [^connection]} = Agents.list_connections(owner, agent_id: agent.id)
      assert {:ok, []} = Agents.list_connections(owner, agent_id: other_agent.id)
    end

    test "owner deletes their connection", %{admin: admin, owner: owner, agent: agent} do
      assert {:ok, connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      assert {:ok, deleted_connection} = Agents.delete_connection(owner, connection)
      assert deleted_connection.id == connection.id
      assert {:ok, []} = Agents.list_connections(owner, agent_id: agent.id)
    end

    test "unrelated owner cannot delete another user's connection", %{
      admin: admin,
      owner: owner,
      agent: agent
    } do
      assert {:ok, connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      {:ok, other_owner} =
        Accounts.create_user(admin, %{
          "email" => "other-delete-connection-owner@example.com",
          "name" => "Other Owner"
        })

      assert {:error, :unauthorized} = Agents.delete_connection(other_owner, connection)
      assert {:ok, [^connection]} = Agents.list_connections(owner, agent_id: agent.id)
    end

    test "create rejects non-admin users", %{admin: admin, owner: owner, agent: agent} do
      non_admin = %User{email: "client@example.com"}

      assert {:error, :unauthorized} =
               Agents.create_connection(non_admin, valid_connection_attrs(agent, owner))

      assert {:ok, _connection} =
               Agents.create_connection(admin, valid_connection_attrs(agent, owner))
    end

    test "owner creates a manual Meta Instagram connection for their own agent", %{
      owner: owner,
      agent: agent
    } do
      assert {:ok, %Connection{} = connection} =
               Agents.create_user_connection(
                 owner,
                 valid_user_connection_attrs(agent, %{
                   "provider" => "google",
                   "channel" => "youtube",
                   "status" => "error",
                   "connected_by_user_id" => Ecto.UUID.generate()
                 })
               )

      assert connection.agent_id == agent.id
      assert connection.connected_by_user_id == owner.id
      assert connection.provider == "meta"
      assert connection.channel == "instagram"
      assert connection.status == "active"
      assert connection.external_account_id == "manual-growth-push-account"
      assert connection.display_name == "Manual Growth Push"
      assert connection.access_token_ref == "placeholder://meta/instagram/manual-growth-push"
    end

    test "owner can create a manual connection with atom keyed attrs", %{
      owner: owner,
      agent: agent
    } do
      assert {:ok, %Connection{} = connection} =
               Agents.create_user_connection(owner, %{
                 agent_id: agent.id,
                 external_account_id: "manual-atom-account",
                 display_name: "Manual Atom",
                 access_token_ref: "placeholder://meta/instagram/manual-atom"
               })

      assert connection.agent_id == agent.id
      assert connection.connected_by_user_id == owner.id
      assert connection.external_account_id == "manual-atom-account"
    end

    test "owner reconnecting the same external account refreshes their connection", %{
      owner: owner,
      agent: agent
    } do
      connected_at = DateTime.utc_now(:second)

      assert {:ok, connection} =
               Agents.create_user_connection(
                 owner,
                 valid_user_connection_attrs(agent, %{
                   "last_connected_at" => DateTime.add(connected_at, -60, :second)
                 })
               )

      assert {:ok, refreshed_connection} =
               Agents.create_user_connection(
                 owner,
                 valid_user_connection_attrs(agent, %{
                   "display_name" => "Manual Growth Push Updated",
                   "last_connected_at" => connected_at
                 })
               )

      assert refreshed_connection.id == connection.id
      assert refreshed_connection.display_name == "Manual Growth Push Updated"
      assert refreshed_connection.last_connected_at == connected_at
      assert {:ok, [_connection]} = Agents.list_connections(owner, agent_id: agent.id)
    end

    test "admin cannot use user connection creation for another user's agent", %{
      admin: admin,
      agent: agent
    } do
      assert {:error, :unauthorized} =
               Agents.create_user_connection(admin, valid_user_connection_attrs(agent))
    end

    test "owner cannot create a connection for another user's agent", %{
      admin: admin,
      owner: owner
    } do
      {:ok, other_owner} =
        Accounts.create_user(admin, %{
          "email" => "other-manual-connection-owner@example.com",
          "name" => "Other Owner"
        })

      {:ok, other_agent} =
        Agents.create_agent(
          admin,
          valid_agent_attrs(other_owner, %{"slug" => "other-manual-connection-agent"})
        )

      assert {:error, :unauthorized} =
               Agents.create_user_connection(owner, valid_user_connection_attrs(other_agent))
    end
  end

  describe "events" do
    setup do
      Gettext.put_locale(GrowthPushRouterWeb.Gettext, "en")

      admin = User.with_runtime_role(%User{email: "admin@example.test"})

      {:ok, owner} =
        Accounts.create_user(admin, %{
          "email" => "event-owner@example.com",
          "name" => "Event Owner"
        })

      {:ok, agent} = Agents.create_agent(admin, valid_agent_attrs(owner))
      {:ok, connection} = Agents.create_connection(admin, valid_connection_attrs(agent, owner))

      %{admin: admin, owner: owner, agent: agent, connection: connection}
    end

    test "creates a raw event for an agent connection", %{agent: agent, connection: connection} do
      received_at = ~U[2026-07-01 12:00:00Z]
      processed_at = ~U[2026-07-01 12:01:00Z]

      payload = %{
        "object" => "instagram",
        "entry" => [
          %{
            "id" => "17841400000000000",
            "changes" => [%{"value" => %{"text" => "hello"}}]
          }
        ]
      }

      assert {:ok, %Event{} = event} =
               Agents.create_connection_event(
                 agent,
                 connection,
                 valid_event_attrs(%{
                   "connection_id" => Ecto.UUID.generate(),
                   "provider" => "google",
                   "channel" => "youtube",
                   "event_type" => " Message_Received ",
                   "external_event_id" => " Evt-001 ",
                   "payload" => payload,
                   "status" => " Processed ",
                   "received_at" => received_at,
                   "processed_at" => processed_at
                 })
               )

      assert event.connection_id == connection.id
      assert event.provider == "meta"
      assert event.channel == "instagram"
      assert event.event_type == "message_received"
      assert event.external_event_id == "Evt-001"
      assert event.payload == payload
      assert event.status == "processed"
      assert event.stored_by == "edge"
      assert is_integer(event.sequence)
      assert event.received_at == received_at
      assert event.processed_at == processed_at

      assert event |> Repo.preload(:connection) |> Map.fetch!(:connection) == connection
    end

    test "defaults operational event fields", %{agent: agent, connection: connection} do
      assert {:ok, event} =
               Agents.create_connection_event(agent, connection, %{
                 "event_type" => "story_mention"
               })

      assert event.status == "received"
      assert event.stored_by == "edge"
      assert event.payload == %{}
      assert event.received_at
      assert event.processed_at == nil
    end

    test "creates an agent-side event for local consumers", %{
      agent: agent,
      connection: connection
    } do
      assert {:ok, %Event{} = event} =
               Agents.create_agent_event(
                 agent,
                 connection,
                 valid_event_attrs(%{
                   "stored_by" => "edge",
                   "status" => "processed"
                 })
               )

      assert event.connection_id == connection.id
      assert event.provider == "meta"
      assert event.channel == "instagram"
      assert event.stored_by == "agent"
      assert event.status == "processed"
      assert is_integer(event.sequence)
    end

    test "marks edge events as synced after agent handoff", %{
      agent: agent,
      connection: connection
    } do
      assert {:ok, event} = Agents.create_connection_event(agent, connection, valid_event_attrs())

      assert {:ok, synced_event} = Agents.mark_event_synced(agent, event)
      assert synced_event.id == event.id
      assert synced_event.status == "synced"
      assert synced_event.stored_by == "edge"
      assert synced_event.processed_at
    end

    test "does not mark agent-side events as synced", %{
      agent: agent,
      connection: connection
    } do
      assert {:ok, event} = Agents.create_agent_event(agent, connection, valid_event_attrs())

      assert {:error, :unauthorized} = Agents.mark_event_synced(agent, event)
    end

    test "validates event status", %{agent: agent, connection: connection} do
      assert {:error, changeset} =
               Agents.create_connection_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"status" => "pending"})
               )

      assert "is not a valid event status" in errors_on(changeset).status
    end

    test "validates event storage owner", %{connection: connection} do
      assert changeset =
               Event.changeset(%Event{}, %{
                 "connection_id" => connection.id,
                 "provider" => "meta",
                 "channel" => "instagram",
                 "event_type" => "message_received",
                 "payload" => %{},
                 "stored_by" => "crm"
               })

      refute changeset.valid?
      assert "is not a valid event storage owner" in errors_on(changeset).stored_by
    end

    test "requires a connection owned by the acting agent", %{agent: agent} do
      missing_connection = %Connection{id: Ecto.UUID.generate()}

      assert {:error, :unauthorized} =
               Agents.create_connection_event(agent, missing_connection, valid_event_attrs())

      assert {:error, :unauthorized} =
               Agents.create_connection_event(agent, "not-a-uuid", valid_event_attrs())
    end

    test "create event rejects user actors including admins", %{
      admin: admin,
      owner: owner,
      connection: connection
    } do
      assert {:error, :unauthorized} =
               Agents.create_connection_event(admin, connection, valid_event_attrs())

      assert {:error, :unauthorized} =
               Agents.create_connection_event(owner, connection, valid_event_attrs())
    end

    test "deleting a connection deletes its events", %{
      agent: agent,
      owner: owner,
      connection: connection
    } do
      assert {:ok, event} = Agents.create_connection_event(agent, connection, valid_event_attrs())

      assert {:ok, _deleted_connection} = Agents.delete_connection(owner, connection)
      refute Repo.get(Event, event.id)
    end

    test "agent can list its events with filters", %{agent: agent, connection: connection} do
      assert {:ok, event} =
               Agents.create_connection_event(
                 agent,
                 connection,
                 valid_event_attrs(%{
                   "event_type" => "comment_received",
                   "external_event_id" => "event-list-1",
                   "status" => "failed"
                 })
               )

      assert {:ok, internal_event} =
               Agents.create_agent_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"external_event_id" => "internal-event-list-1"})
               )

      assert {:ok, [^event]} = Agents.list_events(agent, id: event.id)
      assert {:ok, [^event]} = Agents.list_events(agent, connection_id: connection.id)
      assert {:ok, [^event]} = Agents.list_events(agent, provider: "Meta")
      assert {:ok, [^event]} = Agents.list_events(agent, channel: "Instagram")
      assert {:ok, [^event]} = Agents.list_events(agent, status: "Failed")
      assert {:ok, [^event]} = Agents.list_events(agent, stored_by: "Edge")
      assert {:ok, []} = Agents.list_events(agent, stored_by: "agent")
      assert {:ok, [^event]} = Agents.list_events(agent, event_type: "Comment_Received")
      assert {:ok, [^event]} = Agents.list_events(agent, external_event_id: " event-list-1 ")
      assert {:ok, []} = Agents.list_events(agent, id: internal_event.id)

      assert {:ok, []} =
               Agents.list_events(agent,
                 external_event_id: "internal-event-list-1",
                 stored_by: "agent"
               )

      assert {:ok, [^event]} = Agents.list_events(agent, unsupported: "ignored")
      assert {:ok, []} = Agents.list_events(agent, connection_id: "not-a-uuid")
    end

    test "agent consumers list agent-side events after a sequence", %{
      admin: admin,
      agent: agent,
      connection: connection
    } do
      assert {:ok, _edge_event} =
               Agents.create_connection_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"external_event_id" => "consumer-edge-event"})
               )

      assert {:ok, first_event} =
               Agents.create_agent_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"external_event_id" => "consumer-agent-event-1"})
               )

      assert {:ok, second_event} =
               Agents.create_agent_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"external_event_id" => "consumer-agent-event-2"})
               )

      {:ok, other_owner} =
        Accounts.create_user(admin, %{
          "email" => "consumer-other-event-owner@example.com",
          "name" => "Other Consumer Event Owner"
        })

      {:ok, other_agent} =
        Agents.create_agent(
          admin,
          valid_agent_attrs(other_owner, %{"slug" => "consumer-other-event-agent"})
        )

      {:ok, other_connection} =
        Agents.create_connection(
          admin,
          valid_connection_attrs(other_agent, other_owner, %{
            "external_account_id" => "consumer-other-event-account"
          })
        )

      assert {:ok, _other_event} =
               Agents.create_agent_event(
                 other_agent,
                 other_connection,
                 valid_event_attrs(%{"external_event_id" => "consumer-other-event"})
               )

      assert {:ok, [^first_event]} = Agents.list_agent_events_after(agent, 0, limit: 1)
      assert {:ok, [^second_event]} = Agents.list_agent_events_after(agent, first_event.sequence)
      assert {:ok, []} = Agents.list_agent_events_after(agent, second_event.sequence)
      assert {:error, :unauthorized} = Agents.list_agent_events_after(%User{}, 0)
    end

    test "admin and owner can list visible events", %{
      admin: admin,
      owner: owner,
      agent: agent,
      connection: connection
    } do
      {:ok, other_owner} =
        Accounts.create_user(admin, %{
          "email" => "other-visible-event-owner@example.com",
          "name" => "Other Event Owner"
        })

      {:ok, other_agent} =
        Agents.create_agent(
          admin,
          valid_agent_attrs(other_owner, %{"slug" => "other-visible-event-agent"})
        )

      {:ok, other_connection} =
        Agents.create_connection(
          admin,
          valid_connection_attrs(other_agent, other_owner, %{
            "external_account_id" => "other-visible-event-account"
          })
        )

      assert {:ok, event} =
               Agents.create_connection_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"received_at" => ~U[2026-07-01 12:00:00Z]})
               )

      assert {:ok, internal_event} =
               Agents.create_agent_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"external_event_id" => "internal-visible-event"})
               )

      assert {:ok, other_event} =
               Agents.create_connection_event(
                 other_agent,
                 other_connection,
                 valid_event_attrs(%{
                   "external_event_id" => "other-visible-event",
                   "received_at" => ~U[2026-07-01 12:01:00Z]
                 })
               )

      assert {:ok, events} = Agents.list_events(admin)
      assert Enum.map(events, & &1.id) == [other_event.id, event.id]
      assert {:ok, [^event]} = Agents.list_events(owner)
      assert {:ok, [^event]} = Agents.list_events(owner, id: event.id)
      assert {:ok, []} = Agents.list_events(admin, id: internal_event.id, stored_by: "agent")
      assert {:ok, []} = Agents.list_events(owner, id: internal_event.id, stored_by: "agent")
      assert {:ok, []} = Agents.list_events(owner, id: other_event.id)
    end

    test "fetch event respects actor visibility", %{
      admin: admin,
      owner: owner,
      agent: agent,
      connection: connection
    } do
      assert {:ok, event} = Agents.create_connection_event(agent, connection, valid_event_attrs())

      assert {:ok, internal_event} =
               Agents.create_agent_event(
                 agent,
                 connection,
                 valid_event_attrs(%{"external_event_id" => "internal-fetch-event"})
               )

      {:ok, other_owner} =
        Accounts.create_user(admin, %{
          "email" => "other-fetch-event-owner@example.com",
          "name" => "Other Event Owner"
        })

      assert {:ok, ^event} = Agents.fetch_event(admin, event.id)
      assert {:ok, ^event} = Agents.fetch_event(owner, event.id)
      assert {:ok, ^event} = Agents.fetch_event(agent, event.id)
      assert {:error, :unauthorized} = Agents.fetch_event(admin, internal_event.id)
      assert {:error, :unauthorized} = Agents.fetch_event(owner, internal_event.id)
      assert {:error, :unauthorized} = Agents.fetch_event(agent, internal_event.id)
      assert {:error, :unauthorized} = Agents.fetch_event(other_owner, event.id)
      assert {:error, :unauthorized} = Agents.fetch_event(owner, Ecto.UUID.generate())
      assert {:error, :unauthorized} = Agents.fetch_event(owner, "not-a-uuid")
    end

    test "agent can list only events for its connections", %{
      admin: admin,
      agent: agent,
      connection: connection
    } do
      {:ok, other_owner} =
        Accounts.create_user(admin, %{
          "email" => "other-event-owner@example.com",
          "name" => "Other Event Owner"
        })

      {:ok, other_agent} =
        Agents.create_agent(
          admin,
          valid_agent_attrs(other_owner, %{"slug" => "other-event-agent"})
        )

      {:ok, other_connection} =
        Agents.create_connection(
          admin,
          valid_connection_attrs(other_agent, other_owner, %{
            "external_account_id" => "other-event-account"
          })
        )

      assert {:ok, event} = Agents.create_connection_event(agent, connection, valid_event_attrs())

      assert {:ok, _other_event} =
               Agents.create_connection_event(
                 other_agent,
                 other_connection,
                 valid_event_attrs(%{"external_event_id" => "other-event"})
               )

      assert {:ok, [^event]} = Agents.list_events(agent)
      assert {:ok, [^event]} = Agents.list_events(agent, connection_id: connection.id)
      assert {:ok, []} = Agents.list_events(agent, connection_id: other_connection.id)
      assert {:ok, []} = Agents.list_events(other_agent, connection_id: connection.id)

      assert {:error, :unauthorized} =
               Agents.create_connection_event(agent, other_connection, valid_event_attrs())
    end

    test "list events rejects invalid actors" do
      assert {:error, :unauthorized} = Agents.list_events(%User{email: "client@example.com"})
      assert {:error, :unauthorized} = Agents.list_events(nil)
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

  defp valid_connection_attrs(%Agent{} = agent, %User{} = connected_by_user, attrs \\ %{}) do
    Map.merge(
      %{
        "agent_id" => agent.id,
        "connected_by_user_id" => connected_by_user.id,
        "provider" => "meta",
        "channel" => "instagram",
        "external_account_id" => "growth-push-account",
        "display_name" => "Growth Push",
        "access_token_ref" => "vault://meta/instagram/growth-push"
      },
      attrs
    )
  end

  defp valid_user_connection_attrs(%Agent{} = agent, attrs \\ %{}) do
    Map.merge(
      %{
        "agent_id" => agent.id,
        "external_account_id" => "manual-growth-push-account",
        "display_name" => "Manual Growth Push",
        "access_token_ref" => "placeholder://meta/instagram/manual-growth-push"
      },
      attrs
    )
  end

  defp valid_event_attrs(attrs \\ %{}) do
    Map.merge(
      %{
        "event_type" => "message_received",
        "external_event_id" => "event-1",
        "payload" => %{"entry" => [%{"id" => "17841400000000000"}]}
      },
      attrs
    )
  end
end
