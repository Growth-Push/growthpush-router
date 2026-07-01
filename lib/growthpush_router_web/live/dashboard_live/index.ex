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
           |> close_delete_connection_modal()
           |> assign_dashboard_data()}
        end

      _ ->
        {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("request_delete_connection", %{"id" => id}, socket) do
    request_delete_connection(socket, id)
  end

  def handle_event(
        "validate_delete_connection",
        %{"connection_delete" => %{"confirmation" => confirmation}},
        socket
      ) do
    {:noreply, assign(socket, :connection_delete_confirmation, confirmation)}
  end

  def handle_event("cancel_delete_connection", _params, socket) do
    {:noreply, close_delete_connection_modal(socket)}
  end

  def handle_event(
        "confirm_delete_connection",
        %{"connection_delete" => %{"confirmation" => confirmation}},
        socket
      ) do
    confirm_delete_connection(socket, confirmation)
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
                    <th class="text-right">{gettext(".dashboard.connection_actions")}</th>
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
                    <td class="text-right">
                      <button
                        type="button"
                        class="btn btn-xs btn-error"
                        phx-click="request_delete_connection"
                        phx-value-id={connection.id}
                      >
                        <.icon name="hero-trash" class="size-4" />
                        {gettext(".dashboard.connection_delete")}
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="flex justify-end">
              <.link href={~p"/connect/instagram?agent_id=#{agent.id}"} class="btn btn-sm btn-primary">
                <.icon name="hero-link" class="size-4" />
                {gettext(".dashboard.instagram_oauth_placeholder")}
              </.link>
            </div>
          </div>
        </.section_card>
      </section>

      <.confirm_modal
        :if={@connection_delete_modal?}
        id="delete-connection-modal"
        title={gettext(".dashboard.connection_delete_title")}
        body={
          gettext(".dashboard.connection_delete_body",
            account: @connection_delete_label || gettext(".dashboard.connection_unknown_account")
          )
        }
        confirmation_label={gettext(".dashboard.connection_delete_confirmation_label")}
        confirmation_value={gettext(".dashboard.connection_delete_confirmation_value")}
        typed_value={@connection_delete_confirmation}
        form_name={:connection_delete}
        change_event="validate_delete_connection"
        submit_event="confirm_delete_connection"
        cancel_event="cancel_delete_connection"
        confirm_text={gettext(".dashboard.connection_delete")}
        cancel_text={gettext(".dashboard.connection_delete_cancel")}
      />

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp assign_dashboard_data(socket) do
    case Agents.list_agents(socket.assigns.current_user) do
      {:ok, agents} ->
        connections_by_agent_id = connections_by_agent_id(socket.assigns.current_user, agents)

        socket
        |> assign(:agents, agents)
        |> assign(:connections_by_agent_id, connections_by_agent_id)

      {:error, :unauthorized} ->
        socket
        |> assign(:agents, [])
        |> assign(:connections_by_agent_id, %{})
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

  defp request_delete_connection(socket, id) do
    case Agents.fetch_connection(socket.assigns.current_user, id) do
      {:ok, %Connection{} = connection} ->
        {:noreply,
         assign(socket,
           connection_delete_modal?: true,
           connection_delete_confirmation: "",
           connection_delete_id: connection.id,
           connection_delete_label: connection_delete_label(connection)
         )}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".dashboard.connection_delete_failed"))}
    end
  end

  defp confirm_delete_connection(socket, confirmation) do
    expected_confirmation = gettext(".dashboard.connection_delete_confirmation_value")

    if confirmation == expected_confirmation && socket.assigns.connection_delete_id do
      do_delete_connection(socket, socket.assigns.connection_delete_id)
    else
      {:noreply, assign(socket, :connection_delete_confirmation, confirmation)}
    end
  end

  defp do_delete_connection(socket, id) do
    with {:ok, connection} <- Agents.fetch_connection(socket.assigns.current_user, id),
         {:ok, _deleted_connection} <-
           Agents.delete_connection(socket.assigns.current_user, connection) do
      {:noreply,
       socket
       |> close_delete_connection_modal()
       |> put_flash(:info, gettext(".dashboard.connection_deleted"))
       |> assign_dashboard_data()}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".dashboard.connection_delete_failed"))}
    end
  end

  defp connections_for(connections_by_agent_id, %Agent{id: agent_id}) do
    Map.get(connections_by_agent_id, agent_id, [])
  end

  defp connection_label(%Connection{provider: "meta", channel: "instagram"}) do
    gettext(".dashboard.connection_meta_instagram")
  end

  defp connection_label(%Connection{provider: provider, channel: channel}) do
    "#{provider} / #{channel}"
  end

  defp connection_delete_label(%Connection{display_name: display_name})
       when is_binary(display_name) and display_name != "" do
    display_name
  end

  defp connection_delete_label(%Connection{external_account_id: external_account_id})
       when is_binary(external_account_id) and external_account_id != "" do
    external_account_id
  end

  defp connection_delete_label(_connection), do: gettext(".dashboard.connection_unknown_account")

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

  defp close_delete_connection_modal(socket) do
    assign(socket,
      connection_delete_modal?: false,
      connection_delete_confirmation: "",
      connection_delete_id: nil,
      connection_delete_label: nil
    )
  end
end
