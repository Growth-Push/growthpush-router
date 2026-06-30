defmodule GrowthPushRouterWeb.DashboardLive.Index do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Agent
  alias GrowthPushRouter.Agents.Connection

  @impl true
  def mount(_params, session, socket) do
    case Accounts.get_user(session["user_id"]) do
      %User{} = user ->
        if User.admin?(user) do
          {:ok, redirect(socket, to: ~p"/admin/users")}
        else
          subscribe_to_live_socket(socket, session)

          {:ok,
           socket
           |> assign(:current_user, user)
           |> assign_dashboard_data()}
        end

      _ ->
        {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_event(
        "validate_connection",
        %{"agent_id" => agent_id, "connection" => connection_params},
        socket
      ) do
    {:noreply, validate_connection(socket, agent_id, connection_params)}
  end

  def handle_event(
        "save_connection",
        %{"agent_id" => agent_id, "connection" => connection_params},
        socket
      ) do
    save_connection(socket, agent_id, connection_params)
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
        <.section_card title={gettext(".dashboard.account_title")}>
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
        </.section_card>

        <.section_card
          title={gettext(".dashboard.connections_title")}
          subtitle={gettext(".dashboard.connections_subtitle")}
          class="mt-6"
        >
          <.info_box :if={@agents == []}>
            {gettext(".dashboard.no_agents")}
          </.info_box>

          <div
            :for={agent <- @agents}
            class="space-y-4 border-t border-base-300 py-5 first:border-t-0 first:pt-0 last:pb-0"
          >
            <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p class="text-sm text-base-content/60">{gettext(".dashboard.agent_label")}</p>
                <h3 class="text-lg font-semibold">{agent.slug}</h3>
                <p class="mt-1 break-all text-sm text-base-content/70">{agent.endpoint_url}</p>
              </div>
              <.status_badge status={agent.status} label={agent_status_label(agent.status)} />
            </div>

            <div :if={connections_for(@connections_by_agent_id, agent) != []} class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>{gettext(".dashboard.connection_provider")}</th>
                    <th>{gettext(".dashboard.connection_account")}</th>
                    <th>{gettext(".dashboard.connection_status")}</th>
                    <th>{gettext(".dashboard.connection_connected_at")}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={connection <- connections_for(@connections_by_agent_id, agent)}>
                    <td>{connection_label(connection)}</td>
                    <td>
                      <span class="font-medium">{connection.display_name}</span>
                      <span class="block text-xs text-base-content/60">
                        {connection.external_account_id}
                      </span>
                    </td>
                    <td>
                      <.status_badge
                        status={connection.status}
                        label={connection_status_label(connection.status)}
                      />
                    </td>
                    <td>{format_datetime(connection.last_connected_at)}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <.form
              :if={!instagram_connected?(@connections_by_agent_id, agent)}
              id={"instagram-connection-form-#{agent.id}"}
              for={connection_form(@connection_forms, agent)}
              phx-change="validate_connection"
              phx-submit="save_connection"
              phx-value-agent_id={agent.id}
              class="space-y-4 rounded-md border border-base-300 p-4"
            >
              <input type="hidden" name="agent_id" value={agent.id} />

              <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <h4 class="font-semibold">{gettext(".dashboard.instagram_form_title")}</h4>
                  <p class="mt-1 text-sm text-base-content/70">
                    {gettext(".dashboard.instagram_form_subtitle")}
                  </p>
                </div>
                <.link href={~p"/connect/instagram"} class="btn btn-sm btn-primary btn-soft">
                  <.icon name="hero-link" class="size-4" />
                  {gettext(".dashboard.instagram_oauth_placeholder")}
                </.link>
              </div>

              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={connection_form(@connection_forms, agent)[:external_account_id]}
                  type="text"
                  label={gettext(".dashboard.instagram_external_account_id")}
                  required
                />
                <.input
                  field={connection_form(@connection_forms, agent)[:display_name]}
                  type="text"
                  label={gettext(".dashboard.instagram_display_name")}
                  required
                />
              </div>
              <.input
                field={connection_form(@connection_forms, agent)[:access_token_ref]}
                type="text"
                label={gettext(".dashboard.instagram_access_token_ref")}
                placeholder={gettext(".dashboard.instagram_access_token_ref_placeholder")}
                required
              />
              <.info_box>{gettext(".dashboard.instagram_token_ref_help")}</.info_box>

              <div class="flex justify-end">
                <.button class="btn btn-primary">
                  <.icon name="hero-plus" class="size-4" />
                  {gettext(".dashboard.instagram_save")}
                </.button>
              </div>
            </.form>
          </div>
        </.section_card>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp validate_connection(socket, agent_id, connection_params) do
    with %Agent{} = agent <- find_agent(socket.assigns.agents, agent_id) do
      form =
        %Connection{}
        |> Agents.change_connection(
          connection_attrs(socket.assigns.current_user, agent, connection_params)
        )
        |> Map.put(:action, :validate)
        |> Phoenix.Component.to_form()

      put_connection_form(socket, agent.id, form)
    else
      _ -> put_flash(socket, :error, gettext(".dashboard.agent_not_found"))
    end
  end

  defp save_connection(socket, agent_id, connection_params) do
    with %Agent{} = agent <- find_agent(socket.assigns.agents, agent_id) do
      params = Map.put(connection_params, "agent_id", agent.id)

      case Agents.create_user_connection(socket.assigns.current_user, params) do
        {:ok, _connection} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext(".dashboard.instagram_connected"))
           |> assign_dashboard_data()}

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, gettext(".auth.authentication_required"))}

        {:error, %Ecto.Changeset{} = changeset} ->
          form =
            changeset
            |> Map.put(:action, :insert)
            |> Phoenix.Component.to_form()

          {:noreply, put_connection_form(socket, agent.id, form)}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, gettext(".dashboard.agent_not_found"))}
    end
  end

  defp assign_dashboard_data(socket) do
    case Agents.list_agents(socket.assigns.current_user) do
      {:ok, agents} ->
        connections_by_agent_id = connections_by_agent_id(socket.assigns.current_user, agents)

        socket
        |> assign(:agents, agents)
        |> assign(:connections_by_agent_id, connections_by_agent_id)
        |> assign(:connection_forms, connection_forms(socket.assigns.current_user, agents))

      {:error, :unauthorized} ->
        socket
        |> assign(:agents, [])
        |> assign(:connections_by_agent_id, %{})
        |> assign(:connection_forms, %{})
        |> put_flash(:error, gettext(".auth.authentication_required"))
    end
  end

  defp connections_by_agent_id(%User{} = user, agents) do
    Map.new(agents, fn %Agent{} = agent ->
      connections =
        case Agents.list_connections(user, agent_id: agent.id) do
          {:ok, connections} -> connections
          {:error, :unauthorized} -> []
        end

      {agent.id, connections}
    end)
  end

  defp connection_forms(%User{} = user, agents) do
    Map.new(agents, fn %Agent{} = agent ->
      form =
        %Connection{}
        |> Agents.change_connection(connection_attrs(user, agent, %{}))
        |> Phoenix.Component.to_form()

      {agent.id, form}
    end)
  end

  defp put_connection_form(socket, agent_id, form) do
    update(socket, :connection_forms, &Map.put(&1, agent_id, form))
  end

  defp connection_attrs(%User{} = user, %Agent{} = agent, attrs) do
    attrs = stringify_keys(attrs)

    Map.merge(attrs, %{
      "agent_id" => agent.id,
      "connected_by_user_id" => user.id,
      "provider" => "meta",
      "channel" => "instagram",
      "status" => "active"
    })
  end

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(_attrs), do: %{}

  defp find_agent(agents, agent_id), do: Enum.find(agents, &(&1.id == agent_id))

  defp connections_for(connections_by_agent_id, %Agent{id: agent_id}) do
    Map.get(connections_by_agent_id, agent_id, [])
  end

  defp connection_form(connection_forms, %Agent{id: agent_id}) do
    Map.fetch!(connection_forms, agent_id)
  end

  defp instagram_connected?(connections_by_agent_id, %Agent{} = agent) do
    connections_by_agent_id
    |> connections_for(agent)
    |> Enum.any?(&(&1.provider == "meta" and &1.channel == "instagram"))
  end

  defp connection_label(%Connection{provider: "meta", channel: "instagram"}) do
    gettext(".dashboard.connection_meta_instagram")
  end

  defp connection_label(%Connection{provider: provider, channel: channel}) do
    "#{provider} / #{channel}"
  end

  defp agent_status_label("active"), do: gettext(".dashboard.agent_status_active")
  defp agent_status_label("inactive"), do: gettext(".dashboard.agent_status_inactive")
  defp agent_status_label("error"), do: gettext(".dashboard.agent_status_error")
  defp agent_status_label(status), do: status

  defp connection_status_label("active"), do: gettext(".dashboard.connection_status_active")
  defp connection_status_label("inactive"), do: gettext(".dashboard.connection_status_inactive")
  defp connection_status_label("error"), do: gettext(".dashboard.connection_status_error")
  defp connection_status_label(status), do: status

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  defp subscribe_to_live_socket(socket, %{"live_socket_id" => live_socket_id})
       when is_binary(live_socket_id) do
    if connected?(socket) do
      GrowthPushRouterWeb.Endpoint.subscribe(live_socket_id)
    end
  end

  defp subscribe_to_live_socket(_socket, _session), do: :ok
end
