defmodule GrowthPushRouterWeb.ErrorHTMLTest do
  use GrowthPushRouterWeb.ConnCase, async: true
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    assert render_to_string(GrowthPushRouterWeb.ErrorHTML, "404", "html", []) ==
             gettext("Not Found")
  end

  test "renders 500.html" do
    assert render_to_string(GrowthPushRouterWeb.ErrorHTML, "500", "html", []) ==
             gettext("Internal Server Error")
  end
end
