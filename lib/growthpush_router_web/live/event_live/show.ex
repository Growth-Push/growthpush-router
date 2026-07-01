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
         |> assign(:flow_steps, [])
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

        <.section_card
          title={gettext(".events.flow_title")}
          subtitle={gettext(".events.flow_subtitle")}
        >
          <ol class="flex flex-col gap-3 md:flex-row md:items-center md:gap-2">
            <li
              :for={{step, index} <- Enum.with_index(@flow_steps)}
              class="flex items-center gap-2"
            >
              <div class={[
                "flex min-w-36 items-center gap-3 rounded-md border px-3 py-2",
                flow_step_class(step.state)
              ]}>
                <.icon name={flow_step_icon(step.state)} class="size-5 shrink-0" />
                <div class="min-w-0">
                  <div class="truncate text-sm font-semibold">{step.label}</div>
                  <div class="text-xs opacity-70">{step.caption}</div>
                </div>
              </div>
              <.icon
                :if={index < length(@flow_steps) - 1}
                name="hero-arrow-right"
                class="hidden size-4 text-base-content/40 md:block"
              />
            </li>
          </ol>
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
    case fetch_edge_event(socket.assigns.current_user, id) do
      {:ok, %Event{} = event} ->
        assign(socket,
          event: event,
          flow_steps: event_flow_steps(event),
          payload_json: Jason.encode!(event.payload || %{}, pretty: true)
        )

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext(".events.not_found"))
        |> redirect(to: fallback_events_path(socket.assigns.current_user))
    end
  end

  defp fetch_edge_event(%User{} = user, id) when is_binary(id) do
    case Agents.list_events(user, id: id, stored_by: "edge") do
      {:ok, [%Event{} = event]} -> {:ok, event}
      {:ok, []} -> {:error, :unauthorized}
      {:error, :unauthorized} -> {:error, :unauthorized}
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
  defp event_status_label("synced"), do: gettext(".events.status_synced")
  defp event_status_label("processing"), do: gettext(".events.status_processing")
  defp event_status_label("processed"), do: gettext(".events.status_processed")
  defp event_status_label("failed"), do: gettext(".events.status_failed")
  defp event_status_label("ignored"), do: gettext(".events.status_ignored")
  defp event_status_label(status), do: status

  defp event_flow_steps(%Event{} = event) do
    [
      %{
        label: source_label(event),
        caption: gettext(".events.flow_sent"),
        state: :done
      },
      %{
        label: gettext(".events.flow_router"),
        caption: router_flow_caption(event.status),
        state: router_flow_state(event.status)
      },
      %{
        label: gettext(".events.flow_agent"),
        caption: agent_flow_caption(event.status),
        state: agent_flow_state(event.status)
      },
      %{
        label: gettext(".events.flow_error"),
        caption: error_flow_caption(event.status),
        state: error_flow_state(event.status)
      }
    ]
  end

  defp source_label(%Event{channel: "instagram"}), do: gettext(".events.flow_source_instagram")
  defp source_label(%Event{channel: "whatsapp"}), do: gettext(".events.flow_source_whatsapp")
  defp source_label(%Event{channel: "email"}), do: gettext(".events.flow_source_email")
  defp source_label(%Event{channel: "mail"}), do: gettext(".events.flow_source_email")

  defp source_label(%Event{provider: provider}) when is_binary(provider),
    do: String.upcase(provider)

  defp source_label(_event), do: gettext(".events.flow_source")

  defp router_flow_caption("failed"), do: gettext(".events.flow_router_failed")
  defp router_flow_caption("synced"), do: gettext(".events.flow_router_synced")
  defp router_flow_caption("processed"), do: gettext(".events.flow_router_synced")
  defp router_flow_caption("ignored"), do: gettext(".events.flow_router_ignored")
  defp router_flow_caption(_status), do: gettext(".events.flow_router_received")

  defp router_flow_state("failed"), do: :done
  defp router_flow_state("synced"), do: :done
  defp router_flow_state("processed"), do: :done
  defp router_flow_state(_status), do: :current

  defp agent_flow_caption("failed"), do: gettext(".events.flow_agent_skipped")
  defp agent_flow_caption("synced"), do: gettext(".events.flow_agent_received")
  defp agent_flow_caption("processed"), do: gettext(".events.flow_agent_processed")
  defp agent_flow_caption(_status), do: gettext(".events.flow_pending")

  defp agent_flow_state("synced"), do: :current
  defp agent_flow_state("processed"), do: :done
  defp agent_flow_state(_status), do: :pending

  defp error_flow_caption("failed"), do: gettext(".events.flow_error_active")
  defp error_flow_caption(_status), do: gettext(".events.flow_no_error")

  defp error_flow_state("failed"), do: :error
  defp error_flow_state(_status), do: :pending

  defp flow_step_class(:done), do: "border-success bg-success text-success-content"
  defp flow_step_class(:current), do: "border-info/40 bg-info/10 text-info"
  defp flow_step_class(:error), do: "border-error/40 bg-error/10 text-error"
  defp flow_step_class(:pending), do: "border-base-300 bg-base-100 text-base-content/50"

  defp flow_step_icon(:done), do: "hero-check-circle"
  defp flow_step_icon(:current), do: "hero-arrow-path"
  defp flow_step_icon(:error), do: "hero-x-circle"
  defp flow_step_icon(:pending), do: "hero-clock"

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
