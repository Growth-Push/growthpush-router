defmodule GrowthPushRouterWeb.DataDeletionLive.Show do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext(".data_deletion.page_title"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-8 px-6 py-12">
      <header class="space-y-3">
        <p class="text-sm font-medium text-primary">{gettext(".data_deletion.section")}</p>
        <h1 class="text-3xl font-semibold">{gettext(".data_deletion.title")}</h1>
        <p class="text-base text-base-content/70">{gettext(".data_deletion.subtitle")}</p>
      </header>

      <section class="space-y-4 text-base leading-7 text-base-content/80">
        <p>{gettext(".data_deletion.scope")}</p>
        <p>{gettext(".data_deletion.instructions", contact: privacy_contact())}</p>
        <p>{gettext(".data_deletion.outcome")}</p>
      </section>
    </main>
    """
  end

  defp privacy_contact do
    Application.get_env(:growthpush_router, :privacy_email) ||
      gettext(".data_deletion.operator_contact")
  end
end
