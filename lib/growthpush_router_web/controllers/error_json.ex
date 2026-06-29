defmodule GrowthPushRouterWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  use Gettext, backend: GrowthPushRouterWeb.Gettext

  def render("404.json", _assigns), do: %{errors: %{detail: gettext("Not Found")}}
  def render("500.json", _assigns), do: %{errors: %{detail: gettext("Internal Server Error")}}
  def render(_template, _assigns), do: %{errors: %{detail: gettext("Error")}}
end
