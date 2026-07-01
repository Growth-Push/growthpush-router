defmodule GrowthPushRouterWeb.EventLive.Index do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Event

  @impl true
  def mount(_params, session, socket) do
    case Accounts.get_user(session["user_id"]) do
      %User{} = user ->
        subscribe_to_live_socket(socket, session)

        {:ok,
         socket
         |> assign(:current_user, user)
         |> assign(:events, [])
         |> assign(:connection_id, nil)}

      _ ->
        {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = maybe_redirect_for_scope(socket, params)

    if socket.redirected do
      {:noreply, socket}
    else
      {:noreply, assign_events(socket, params)}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "disconnect"}, socket) do
    {:noreply, redirect(socket, to: ~p"/login")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200">
      <.events_nav current_user={@current_user} />

      <section class="mx-auto w-full max-w-6xl px-4 py-8">
        <.section_card title={page_title(@current_user)} subtitle={gettext(".events.index_subtitle")}>
          <:actions>
            <.link navigate={events_index_path(@current_user)} class="btn btn-sm">
              <.icon name="hero-arrow-path" class="size-4" />
              {gettext(".events.clear_filters")}
            </.link>
          </:actions>

          <.info_box :if={@connection_id}>
            {gettext(".events.filtered_by_connection", connection_id: @connection_id)}
          </.info_box>

          <.info_box :if={@events == []} class={[@connection_id && "mt-4"]}>
            {gettext(".events.empty")}
          </.info_box>

          <div :if={@events != []} class={["overflow-x-auto", @connection_id && "mt-4"]}>
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>{gettext(".events.provider")}</th>
                  <th>{gettext(".events.channel")}</th>
                  <th>{gettext(".events.event_type")}</th>
                  <th>{gettext(".events.external_event_id")}</th>
                  <th>{gettext(".events.status")}</th>
                  <th>{gettext(".events.received_at")}</th>
                  <th class="text-right">{gettext(".events.actions")}</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={event <- @events}>
                  <td>{event.provider}</td>
                  <td>{event.channel}</td>
                  <td class="font-medium">{event.event_type}</td>
                  <td class="max-w-64 break-all">{event.external_event_id || "-"}</td>
                  <td>
                    <.status_badge status={event.status} label={event_status_label(event.status)} />
                  </td>
                  <td>{format_datetime(event.received_at)}</td>
                  <td class="text-right">
                    <.link navigate={event_detail_path(@current_user, event)} class="btn btn-xs">
                      <.icon name="hero-eye" class="size-4" />
                      {gettext(".events.view")}
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.section_card>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp maybe_redirect_for_scope(%{assigns: %{current_user: %User{} = user}} = socket, params) do
    cond do
      socket.assigns.live_action == :index and User.admin?(user) ->
        redirect(socket, to: ~p"/admin/events?#{preserved_query(params)}")

      socket.assigns.live_action == :admin_index and !User.admin?(user) ->
        redirect(socket, to: ~p"/dashboard")

      true ->
        socket
    end
  end

  defp assign_events(socket, params) do
    filters = event_filters(params)

    case Agents.list_events(socket.assigns.current_user, filters) do
      {:ok, events} ->
        assign(socket,
          events: events,
          connection_id: params["connection_id"]
        )

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext(".auth.admin_required"))
        |> redirect(to: ~p"/dashboard")
    end
  end

  defp event_filters(params) do
    params
    |> Map.take(["connection_id"])
    |> Enum.map(fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  defp preserved_query(%{"connection_id" => connection_id}) when is_binary(connection_id) do
    %{connection_id: connection_id}
  end

  defp preserved_query(_params), do: %{}

  defp events_nav(%{current_user: %User{is_admin: true}} = assigns) do
    ~H"""
    <GrowthPushRouterWeb.AdminUserLive.Index.admin_nav current_user={@current_user} />
    """
  end

  defp events_nav(assigns) do
    ~H"""
    <header class="border-b border-base-300 bg-base-100">
      <div class="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <.link navigate={~p"/dashboard"} class="font-semibold">
          {gettext(".dashboard.nav_title")}
        </.link>
        <div class="flex items-center gap-2">
          <.link navigate={~p"/events"} class="btn btn-sm btn-primary btn-soft">
            <.icon name="hero-inbox-stack" class="size-4" />
            {gettext(".events.nav_title")}
          </.link>
          <.link href={~p"/logout"} method="delete" class="btn btn-sm">
            <.icon name="hero-arrow-left-on-rectangle" class="size-4" />
            {gettext(".dashboard.sign_out")}
          </.link>
        </div>
      </div>
    </header>
    """
  end

  defp page_title(%User{is_admin: true}), do: gettext(".events.admin_index_title")
  defp page_title(_user), do: gettext(".events.index_title")

  defp events_index_path(%User{is_admin: true}), do: ~p"/admin/events"
  defp events_index_path(_user), do: ~p"/events"

  defp event_detail_path(%User{is_admin: true}, %Event{} = event), do: ~p"/admin/events/#{event}"
  defp event_detail_path(_user, %Event{} = event), do: ~p"/events/#{event}"

  defp event_status_label("received"), do: gettext(".events.status_received")
  defp event_status_label("processing"), do: gettext(".events.status_processing")
  defp event_status_label("processed"), do: gettext(".events.status_processed")
  defp event_status_label("failed"), do: gettext(".events.status_failed")
  defp event_status_label("ignored"), do: gettext(".events.status_ignored")
  defp event_status_label(status), do: status

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
