defmodule GrowthPushRouterWeb.SessionLive.New do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    email = params["email"] || ""

    {:ok, assign(socket, :email, email)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200 px-4 py-10">
      <section class="mx-auto w-full max-w-md">
        <div class="mb-6">
          <h1 class="text-2xl font-semibold">{gettext(".session.title")}</h1>
          <p class="text-sm text-base-content/70">{gettext(".session.subtitle")}</p>
        </div>

        <.form
          for={%{}}
          as={:user}
          action={~p"/login"}
          class="space-y-4 rounded-lg bg-base-100 p-6 shadow-sm"
        >
          <.input
            name="user[email]"
            id="user_email"
            type="email"
            label={gettext(".session.email")}
            value={@email}
            required
          />
          <.input
            name="user[password]"
            id="user_password"
            type="password"
            label={gettext(".session.password")}
            value=""
            required
          />

          <.button class="btn btn-primary w-full">{gettext(".session.submit")}</.button>

          <.link navigate={~p"/password/setup"} class="block text-center text-sm link">
            {gettext(".session.password_setup_link")}
          </.link>
        </.form>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end
end
