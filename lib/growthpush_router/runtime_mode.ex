defmodule GrowthPushRouter.RuntimeMode do
  @moduledoc """
  Runtime mode helpers for deciding which surfaces this node should serve.
  """

  @type mode :: :edge | :agent | :both
  @type capability :: :edge | :agent

  alias GrowthPushRouter.Helpers

  @valid_modes ~w(edge agent both)a

  @doc """
  Returns the configured runtime mode.

  This reads process-global application runtime configuration, so the happy path
  is covered in regular tests instead of a doctest to avoid mutating shared
  config from doctests.
  """
  @spec mode() :: mode()
  def mode do
    :growthpush_router
    |> Application.get_env(:mode, :both)
    |> normalize!()
  end

  @doc """
  Returns whether a configured mode includes the requested capability.

  ## Examples

      iex> GrowthPushRouter.RuntimeMode.supports?(:edge, :both)
      true

      iex> GrowthPushRouter.RuntimeMode.supports?(:agent, :edge)
      false

  """
  @spec supports?(capability(), mode() | String.t()) :: boolean()
  def supports?(capability, configured_mode)

  def supports?(:edge, configured_mode), do: normalize!(configured_mode) in [:edge, :both]
  def supports?(:agent, configured_mode), do: normalize!(configured_mode) in [:agent, :both]

  @doc """
  Returns whether the current runtime mode includes the requested capability.

  This reads process-global application runtime configuration, so the happy path
  is covered in regular tests instead of a doctest to avoid mutating shared
  config from doctests.
  """
  @spec supports?(capability()) :: boolean()
  def supports?(capability), do: supports?(capability, mode())

  @doc """
  Normalizes supported runtime mode values.

  ## Examples

      iex> GrowthPushRouter.RuntimeMode.normalize!("edge")
      :edge

      iex> GrowthPushRouter.RuntimeMode.normalize!(:both)
      :both

  """
  @spec normalize!(mode() | String.t()) :: mode()
  def normalize!(mode) when mode in @valid_modes, do: mode

  def normalize!(mode) when is_binary(mode) do
    mode
    |> Helpers.normalize_string()
    |> String.to_existing_atom()
    |> normalize!()
  rescue
    ArgumentError -> raise_invalid_mode(mode)
  end

  def normalize!(mode), do: raise_invalid_mode(mode)

  defp raise_invalid_mode(mode) do
    raise ArgumentError,
          "invalid GrowthPush runtime mode #{inspect(mode)}. Expected one of: edge, agent, both"
  end
end
