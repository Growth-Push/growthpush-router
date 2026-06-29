defmodule GrowthPushRouterWeb.ErrorJSONTest do
  use GrowthPushRouterWeb.ConnCase, async: true
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  test "renders 404" do
    assert GrowthPushRouterWeb.ErrorJSON.render("404.json", %{}) == %{
             errors: %{detail: gettext("Not Found")}
           }
  end

  test "renders 500" do
    assert GrowthPushRouterWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: gettext("Internal Server Error")}}
  end
end
