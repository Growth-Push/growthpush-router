defmodule GrowthPushRouterWeb.PrivacyLive.Show do
  @moduledoc false

  use GrowthPushRouterWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext(".privacy.page_title"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-8 px-6 py-12">
      <header class="space-y-3">
        <p class="text-sm font-medium text-primary">{gettext(".privacy.section")}</p>
        <h1 class="text-3xl font-semibold">{gettext(".privacy.title")}</h1>
        <p class="text-base text-base-content/70">{gettext(".privacy.subtitle")}</p>
      </header>

      <section class="space-y-4 text-base leading-7 text-base-content/80">
        <p>{gettext(".privacy.data_use")}</p>
        <p>{gettext(".privacy.data_control")}</p>
        <p>{gettext(".privacy.retention")}</p>
        <p>{gettext(".privacy.deletion", contact: privacy_contact())}</p>
      </section>
    </main>
    """
  end

  defp privacy_contact do
    Application.get_env(:growthpush_router, :privacy_email) ||
      gettext(".privacy.operator_contact")
  end
end
