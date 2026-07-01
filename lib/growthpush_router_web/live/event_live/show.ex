defmodule GrowthPushRouterWeb.EventLive.Show do
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
         |> assign(:event, nil)
         |> assign(:payload_json, "{}")}

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
      {:noreply, assign_event(socket, params)}
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

      <section class="mx-auto w-full max-w-6xl space-y-6 px-4 py-8">
        <.section_card title={gettext(".events.show_title")} subtitle={@event.id}>
          <:actions>
            <.link navigate={events_index_path(@current_user, @event)} class="btn btn-sm">
              <.icon name="hero-arrow-left" class="size-4" />
              {gettext(".events.back_to_events")}
            </.link>
          </:actions>

          <dl class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".events.provider")}</dt>
              <dd class="mt-1 font-medium">{@event.provider}</dd>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".events.channel")}</dt>
              <dd class="mt-1 font-medium">{@event.channel}</dd>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".events.event_type")}</dt>
              <dd class="mt-1 font-medium">{@event.event_type}</dd>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".events.external_event_id")}</dt>
              <dd class="mt-1 break-all font-medium">{@event.external_event_id || "-"}</dd>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".events.status")}</dt>
              <dd class="mt-1">
                <.status_badge status={@event.status} label={event_status_label(@event.status)} />
              </dd>
            </div>
            <div class="rounded-lg border border-base-300 p-4">
              <dt class="text-sm text-base-content/60">{gettext(".events.received_at")}</dt>
              <dd class="mt-1 font-medium">{format_datetime(@event.received_at)}</dd>
            </div>
          </dl>
        </.section_card>

        <.section_card title={gettext(".events.payload_title")}>
          <pre class="max-h-[36rem] overflow-auto rounded-md bg-base-300 p-4 text-xs leading-relaxed"><code>{@payload_json}</code></pre>
        </.section_card>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp maybe_redirect_for_scope(%{assigns: %{current_user: %User{} = user}} = socket, params) do
    cond do
      socket.assigns.live_action == :show and User.admin?(user) ->
        redirect(socket, to: ~p"/admin/events/#{params["id"]}")

      socket.assigns.live_action == :admin_show and !User.admin?(user) ->
        redirect(socket, to: ~p"/dashboard")

      true ->
        socket
    end
  end

  defp assign_event(socket, %{"id" => id}) do
    case Agents.fetch_event(socket.assigns.current_user, id) do
      {:ok, %Event{} = event} ->
        assign(socket,
          event: event,
          payload_json: Jason.encode!(event.payload || %{}, pretty: true)
        )

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext(".events.not_found"))
        |> redirect(to: fallback_events_path(socket.assigns.current_user))
    end
  end

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

  defp events_index_path(%User{is_admin: true}, %Event{connection_id: connection_id}) do
    ~p"/admin/events?connection_id=#{connection_id}"
  end

  defp events_index_path(_user, %Event{connection_id: connection_id}) do
    ~p"/events?connection_id=#{connection_id}"
  end

  defp fallback_events_path(%User{is_admin: true}), do: ~p"/admin/users"
  defp fallback_events_path(_user), do: ~p"/events"

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
