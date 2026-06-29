defmodule GrowthPushRouterWeb.PasswordSetupLive.New do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  @impl true
  def mount(params, _session, socket) do
    email = params["email"] || ""

    {:ok, assign_form(socket, password_form(email))}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      %User{email: user_params["email"]}
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> Phoenix.Component.to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200 px-4 py-10">
      <section class="mx-auto w-full max-w-md">
        <div class="mb-6">
          <h1 class="text-2xl font-semibold">{gettext(".password_setup.title")}</h1>
          <p class="text-sm text-base-content/70">{gettext(".password_setup.subtitle")}</p>
        </div>

        <.form
          for={@form}
          as={:user}
          id="password-setup-form"
          action={~p"/password/setup"}
          phx-change="validate"
          class="space-y-4 rounded-lg bg-base-100 p-6 shadow-sm"
        >
          <.input
            field={@form[:email]}
            type="email"
            label={gettext(".password_setup.email")}
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label={gettext(".password_setup.password")}
            required
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label={gettext(".password_setup.password_confirmation")}
            required
          />

          <.button class="btn btn-primary w-full">{gettext(".password_setup.submit")}</.button>

          <.link navigate={~p"/login"} class="block text-center text-sm link">{gettext(
            ".password_setup.back_to_login"
          )}</.link>
        </.form>
      </section>

      <Layouts.flash_group flash={@flash} />
    </main>
    """
  end

  defp password_form(email) do
    %User{email: email}
    |> Accounts.change_user_password()
    |> Phoenix.Component.to_form()
  end

  defp assign_form(socket, form), do: assign(socket, :form, form)
end
