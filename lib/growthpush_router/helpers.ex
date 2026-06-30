defmodule GrowthPushRouter.Helpers do
  @moduledoc """
  Shared helper functions for GrowthPush Router.
  """

  @doc """
  Normalizes strings for comparisons and stable config values.

  ## Examples

      iex> GrowthPushRouter.Helpers.normalize_string(" Both ")
      "both"

      iex> GrowthPushRouter.Helpers.normalize_string(nil)
      ""

  """
  @spec normalize_string(String.t() | nil) :: String.t()
  def normalize_string(nil), do: ""

  def normalize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end
end
