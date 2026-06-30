defmodule GrowthPushRouterWeb.AdminUserLive.Form do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User
  alias GrowthPushRouter.Agents
  alias GrowthPushRouter.Agents.Agent

  @impl true
  def mount(_params, session, socket) do
    with %User{} = user <- Accounts.get_user(session["user_id"]),
         true <- User.admin?(user) do
      subscribe_to_live_socket(socket, session)

      {:ok,
       assign(socket,
         current_user: user,
         user: nil,
         form: nil,
         agent: nil,
         agent_form: nil,
         agent_delete_modal?: false,
         agent_delete_confirmation: "",
         show_agent_secret?: false
       )}
    else
      _ -> {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)
      |> Phoenix.Component.to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.live_action, user_params)
  end

  def handle_event("validate_agent", %{"agent" => agent_params}, socket) do
    form =
      socket.assigns.agent
      |> Agents.change_agent(agent_params(socket, agent_params))
      |> Map.put(:action, :validate)
      |> Phoenix.Component.to_form()

    {:noreply, assign(socket, :agent_form, form)}
  end

  def handle_event("save_agent", %{"agent" => agent_params}, socket) do
    save_agent(socket, agent_params(socket, agent_params))
  end

  def handle_event("generate_agent_secret", _params, socket) do
    attrs =
      socket.assigns.agent_form
      |> agent_form_params()
      |> Map.put("owner_id", socket.assigns.user.id)
      |> Map.put("shared_secret", generate_secret())

    form =
      socket.assigns.agent
      |> Agents.change_agent(attrs)
      |> Phoenix.Component.to_form()

    {:noreply, assign(socket, :agent_form, form)}
  end

  def handle_event("toggle_agent_secret_visibility", _params, socket) do
    {:noreply, update(socket, :show_agent_secret?, &(!&1))}
  end

  def handle_event("test_agent_endpoint", %{"endpoint_url" => endpoint_url}, socket) do
    socket =
      case test_endpoint_health(endpoint_url) do
        {:ok, status} ->
          put_flash(socket, :info, gettext(".admin_agent_form.endpoint_test_ok", status: status))

        {:error, :blank} ->
          put_flash(socket, :error, gettext(".admin_agent_form.endpoint_test_blank"))

        {:error, {:http_status, status}} ->
          put_flash(
            socket,
            :error,
            gettext(".admin_agent_form.endpoint_test_status", status: status)
          )

        {:error, _reason} ->
          put_flash(socket, :error, gettext(".admin_agent_form.endpoint_test_failed"))
      end

    {:noreply, socket}
  end

  def handle_event("request_delete_agent", _params, socket) do
    {:noreply, assign(socket, agent_delete_modal?: true, agent_delete_confirmation: "")}
  end

  def handle_event(
        "validate_delete_agent",
        %{"agent_delete" => %{"confirmation" => confirmation}},
        socket
      ) do
    {:noreply, assign(socket, :agent_delete_confirmation, confirmation)}
  end

  def handle_event("cancel_delete_agent", _params, socket) do
    {:noreply, close_delete_agent_modal(socket)}
  end

  def handle_event("delete_agent", %{"agent_delete" => %{"confirmation" => confirmation}}, socket) do
    delete_agent(socket, confirmation)
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "disconnect"}, socket) do
    {:noreply, redirect(socket, to: ~p"/login")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200">
      <GrowthPushRouterWeb.AdminUserLive.Index.admin_nav current_user={@current_user} />

      <section class="mx-auto w-full max-w-2xl space-y-6 px-4 py-8">
        <.section_card title={@page_title}>
          <.form
            id="admin-user-form"
            for={@form}
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:email]}
              type="email"
              label={gettext(".admin_user_form.email")}
              required
            />
            <.input
              field={@form[:name]}
              type="text"
              label={gettext(".admin_user_form.name")}
              required
            />
            <.input field={@form[:company]} type="text" label={gettext(".admin_user_form.company")} />

            <div class="flex justify-end gap-2">
              <.link navigate={~p"/admin/users"} class="btn">{gettext(".admin_user_form.cancel")}</.link>
              <.button class="btn btn-primary">{gettext(".admin_user_form.save")}</.button>
            </div>
          </.form>
        </.section_card>

        <.section_card
          :if={@live_action == :edit}
          title={agent_title(@agent)}
          subtitle={gettext(".admin_agent_form.subtitle")}
        >
          <:actions>
            <.status_badge
              :if={@agent && @agent.id}
              status={@agent.status}
              label={agent_status_label(@agent.status)}
            />
          </:actions>

          <.form
            id="admin-agent-form"
            for={@agent_form}
            phx-change="validate_agent"
            phx-submit="save_agent"
            class="space-y-4"
          >
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@agent_form[:slug]}
                type="text"
                label={gettext(".admin_agent_form.slug")}
                placeholder={suggested_agent_slug(@user)}
                required
              />
              <.input
                field={@agent_form[:status]}
                type="select"
                label={gettext(".admin_agent_form.status")}
                options={agent_status_options()}
              />
            </div>
            <div>
              <div class="flex flex-col gap-2 sm:flex-row sm:items-end">
                <div class="min-w-0 flex-1">
                  <.input
                    field={@agent_form[:endpoint_url]}
                    type="url"
                    label={gettext(".admin_agent_form.endpoint_url")}
                    placeholder={gettext(".admin_agent_form.endpoint_url_placeholder")}
                    required
                  />
                </div>
                <.button
                  type="button"
                  phx-click="test_agent_endpoint"
                  phx-value-endpoint_url={
                    Phoenix.HTML.Form.input_value(@agent_form, :endpoint_url) || ""
                  }
                  disabled={!agent_endpoint_url_present?(@agent_form)}
                  class="btn btn-primary btn-soft sm:mb-2"
                >
                  <.icon name="hero-signal" class="size-4" />
                  {gettext(".admin_agent_form.test_endpoint")}
                </.button>
              </div>
              <.info_box>{gettext(".admin_agent_form.endpoint_help")}</.info_box>
            </div>
            <div>
              <div class="flex flex-col gap-2 sm:flex-row sm:items-end">
                <div class="min-w-0 flex-1">
                  <.input
                    field={@agent_form[:shared_secret]}
                    type={agent_secret_input_type(@show_agent_secret?)}
                    label={shared_secret_label(@agent)}
                    placeholder={gettext(".admin_agent_form.shared_secret_placeholder")}
                    required={!(@agent && @agent.id)}
                    autocomplete="new-password"
                  />
                </div>
                <.button
                  type="button"
                  phx-click="generate_agent_secret"
                  class="btn btn-primary btn-soft sm:mb-2"
                >
                  <.icon name="hero-sparkles" class="size-4" />
                  {gettext(".admin_agent_form.generate_secret")}
                </.button>
                <.button
                  type="button"
                  phx-click="toggle_agent_secret_visibility"
                  class="btn btn-primary btn-soft sm:mb-2"
                >
                  <.icon name={agent_secret_visibility_icon(@show_agent_secret?)} class="size-4" />
                  {agent_secret_visibility_label(@show_agent_secret?)}
                </.button>
                <.button
                  type="button"
                  id="copy-agent-secret"
                  phx-hook="ClipboardCopy"
                  data-copy-source="#agent_shared_secret"
                  data-copy-label={gettext(".admin_agent_form.copy_secret")}
                  data-copied-label={gettext(".admin_agent_form.copied_secret")}
                  class="btn btn-primary btn-soft sm:mb-2"
                >
                  <.icon name="hero-clipboard-document" class="size-4" />
                  <span data-copy-button-label>{gettext(".admin_agent_form.copy_secret")}</span>
                </.button>
              </div>
            </div>
            <.info_box>{gettext(".admin_agent_form.shared_secret_help")}</.info_box>

            <div class="flex justify-end gap-2">
              <.link navigate={~p"/admin/users"} class="btn">
                {gettext(".admin_user_form.cancel")}
              </.link>
              <.button class="btn btn-primary">
                {agent_save_label(@agent)}
              </.button>
              <.button
                :if={@agent && @agent.id}
                type="button"
                variant="danger"
                phx-click="request_delete_agent"
              >
                <.icon name="hero-trash" class="size-4" />
                {gettext(".admin_agent_form.delete")}
              </.button>
            </div>
          </.form>
        </.section_card>
      </section>

      <.confirm_modal
        :if={@agent_delete_modal? && @agent && @agent.id}
        id="delete-agent-modal"
        title={gettext(".admin_agent_form.delete_title")}
        body={gettext(".admin_agent_form.delete_body", slug: @agent.slug)}
        confirmation_label={gettext(".admin_agent_form.delete_confirmation_label")}
        confirmation_value={@agent.slug}
        typed_value={@agent_delete_confirmation}
        form_name={:agent_delete}
        change_event="validate_delete_agent"
        submit_event="delete_agent"
        cancel_event="cancel_delete_agent"
        confirm_text={gettext(".admin_agent_form.delete_confirm")}
        cancel_text={gettext(".admin_agent_form.delete_cancel")}
      />

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp apply_action(socket, :new, _params) do
    user = %User{}

    socket
    |> assign(:page_title, gettext(".admin_users.new_title"))
    |> assign(:user, user)
    |> assign_form(Accounts.change_user(user))
    |> assign(:agent, nil)
    |> assign(:agent_form, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Accounts.fetch_user(socket.assigns.current_user, id) do
      {:ok, user} ->
        socket
        |> assign(:page_title, gettext(".admin_users.edit_title"))
        |> assign(:user, user)
        |> assign_form(Accounts.change_user(user))
        |> assign_agent(user)

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext(".auth.admin_required"))
        |> redirect(to: ~p"/dashboard")
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.create_user(socket.assigns.current_user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_users.user_created"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.current_user, socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_users.user_updated"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_agent(socket, agent_params) do
    case socket.assigns.agent do
      %Agent{id: nil} ->
        create_agent(socket, agent_params)

      %Agent{} = agent ->
        update_agent(socket, agent, agent_params)
    end
  end

  defp create_agent(socket, agent_params) do
    case Agents.create_agent(socket.assigns.current_user, agent_params) do
      {:ok, _agent} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_agent_form.created"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_agent_form(socket, changeset)}
    end
  end

  defp update_agent(socket, %Agent{} = agent, agent_params) do
    case Agents.update_agent(socket.assigns.current_user, agent, agent_params) do
      {:ok, _agent} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_agent_form.updated"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_agent_form(socket, changeset)}
    end
  end

  defp delete_agent(socket, confirmation) do
    if confirmation == socket.assigns.agent.slug do
      do_delete_agent(socket)
    else
      {:noreply, assign(socket, :agent_delete_confirmation, confirmation)}
    end
  end

  defp do_delete_agent(socket) do
    case Agents.delete_agent(socket.assigns.current_user, socket.assigns.agent) do
      {:ok, _agent} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext(".admin_agent_form.deleted"))
         |> close_delete_agent_modal()
         |> assign_agent(socket.assigns.user)}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext(".auth.admin_required"))}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, Phoenix.Component.to_form(changeset))
  end

  defp assign_agent(socket, %User{} = user) do
    case Agents.list_agents(socket.assigns.current_user, owner_id: user.id) do
      {:ok, agents} ->
        agent = List.first(agents) || %Agent{owner_id: user.id, slug: suggested_agent_slug(user)}

        socket
        |> assign(:agent, agent)
        |> assign_agent_form(Agents.change_agent(agent))

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext(".auth.admin_required"))
        |> redirect(to: ~p"/dashboard")
    end
  end

  defp assign_agent_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :agent_form, Phoenix.Component.to_form(changeset))
  end

  defp agent_params(socket, params) do
    params
    |> Map.put("owner_id", socket.assigns.user.id)
    |> drop_blank_secret()
  end

  defp drop_blank_secret(%{"shared_secret" => ""} = params),
    do: Map.delete(params, "shared_secret")

  defp drop_blank_secret(params), do: params

  defp agent_form_params(form) do
    %{
      "slug" => Phoenix.HTML.Form.input_value(form, :slug) || "",
      "endpoint_url" => Phoenix.HTML.Form.input_value(form, :endpoint_url) || "",
      "status" => Phoenix.HTML.Form.input_value(form, :status) || "inactive"
    }
  end

  defp generate_secret do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp close_delete_agent_modal(socket) do
    assign(socket, agent_delete_modal?: false, agent_delete_confirmation: "")
  end

  defp test_endpoint_health(endpoint_url) do
    endpoint_url = String.trim(endpoint_url || "")

    cond do
      endpoint_url == "" ->
        {:error, :blank}

      valid_healthcheck_url?(endpoint_url) ->
        endpoint_url
        |> endpoint_health_request()
        |> endpoint_health_result()

      true ->
        {:error, :invalid_url}
    end
  end

  defp endpoint_health_request(endpoint_url) do
    req_options =
      :growthpush_router
      |> Application.get_env(:agent_healthcheck_req_options, [])
      |> Keyword.merge(url: endpoint_url, method: :get, retry: false, receive_timeout: 2_000)

    Req.request(req_options)
  rescue
    ArgumentError -> {:error, :invalid_url}
    URI.Error -> {:error, :invalid_url}
  end

  defp valid_healthcheck_url?(endpoint_url) do
    uri = URI.parse(endpoint_url)

    uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != ""
  end

  defp endpoint_health_result({:ok, %{status: status}}) when status in 200..399, do: {:ok, status}
  defp endpoint_health_result({:ok, %{status: status}}), do: {:error, {:http_status, status}}
  defp endpoint_health_result({:error, reason}), do: {:error, reason}

  defp agent_status_options do
    Enum.map(Agent.statuses(), &{agent_status_label(&1), &1})
  end

  defp agent_status_label("active"), do: gettext(".admin_agent_form.status_active")
  defp agent_status_label("inactive"), do: gettext(".admin_agent_form.status_inactive")
  defp agent_status_label("error"), do: gettext(".admin_agent_form.status_error")
  defp agent_status_label(status), do: status

  defp shared_secret_label(%Agent{id: nil}), do: gettext(".admin_agent_form.shared_secret")
  defp shared_secret_label(%Agent{}), do: gettext(".admin_agent_form.shared_secret_optional")
  defp shared_secret_label(_agent), do: gettext(".admin_agent_form.shared_secret")

  defp agent_save_label(%Agent{id: nil}), do: gettext(".admin_agent_form.create")
  defp agent_save_label(%Agent{}), do: gettext(".admin_agent_form.save")
  defp agent_save_label(_agent), do: gettext(".admin_agent_form.create")

  defp agent_secret_input_type(true), do: "text"
  defp agent_secret_input_type(false), do: "password"

  defp agent_secret_visibility_label(true), do: gettext(".admin_agent_form.hide_secret")
  defp agent_secret_visibility_label(false), do: gettext(".admin_agent_form.show_secret")

  defp agent_secret_visibility_icon(true), do: "hero-eye-slash"
  defp agent_secret_visibility_icon(false), do: "hero-eye"

  defp agent_endpoint_url_present?(form) do
    endpoint_url =
      form
      |> Phoenix.HTML.Form.input_value(:endpoint_url)
      |> to_string()
      |> String.trim()

    endpoint_url != ""
  end

  defp agent_title(%Agent{id: nil}), do: gettext(".admin_agent_form.create_title")
  defp agent_title(%Agent{}), do: gettext(".admin_agent_form.edit_title")
  defp agent_title(_agent), do: gettext(".admin_agent_form.create_title")

  defp suggested_agent_slug(%User{} = user) do
    user
    |> slug_source()
    |> slugify()
    |> append_agent_suffix()
  end

  defp slug_source(%User{company: company}) when is_binary(company) and company != "", do: company
  defp slug_source(%User{name: name}) when is_binary(name) and name != "", do: name

  defp slug_source(%User{email: email}) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
  end

  defp slug_source(_user), do: "client"

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp append_agent_suffix(""), do: "client-agent"
  defp append_agent_suffix(slug), do: "#{slug}-agent"

  defp subscribe_to_live_socket(socket, %{"live_socket_id" => live_socket_id})
       when is_binary(live_socket_id) do
    if connected?(socket) do
      GrowthPushRouterWeb.Endpoint.subscribe(live_socket_id)
    end
  end

  defp subscribe_to_live_socket(_socket, _session), do: :ok
end
