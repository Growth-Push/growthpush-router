defmodule GrowthPushRouter.Seeds do
  @moduledoc false

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  @admin_emails "GROWTHPUSH_ADMIN_EMAILS"

  @doc """
  Runs database seeds from the given environment map.

  ## Examples

      iex> alias GrowthPushRouter.Seeds
      iex> {:ok, %{admins: admins}} = Seeds.run(%{"GROWTHPUSH_ADMIN_EMAILS" => "seed-run-doc@example.com"})
      iex> Enum.map(admins, &{&1.email, &1.name, &1.company})
      [{"seed-run-doc@example.com", "seed-run-doc", "Example"}]

  """
  def run(env \\ System.get_env()) do
    with {:ok, emails} <- admin_emails(env) do
      seed_admins(emails)
    end
  end

  @doc """
  Runs database seeds and raises on failure.

  ## Examples

      iex> alias GrowthPushRouter.Seeds
      iex> %{admins: admins} = Seeds.run!(%{"GROWTHPUSH_ADMIN_EMAILS" => "seed-run-bang-doc@example.com"})
      iex> Enum.map(admins, & &1.email)
      ["seed-run-bang-doc@example.com"]

  """
  def run!(env \\ System.get_env()) do
    case run(env) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, seed_error(reason)
    end
  end

  defp admin_emails(env) do
    env
    |> optional_env(@admin_emails)
    |> parse_admin_emails()
  end

  defp parse_admin_emails(nil), do: {:error, {:missing_env, @admin_emails}}

  defp parse_admin_emails(value) do
    emails =
      value
      |> String.split(",", trim: true)
      |> Enum.map(&User.normalize_email/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    if emails == [] do
      {:error, {:missing_env, @admin_emails}}
    else
      {:ok, emails}
    end
  end

  defp seed_admins(emails) do
    Enum.reduce_while(emails, {:ok, []}, fn email, {:ok, admins} ->
      case Accounts.upsert_seeded_admin(admin_attrs(email)) do
        {:ok, admin} -> {:cont, {:ok, [admin | admins]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, admins} -> {:ok, %{admins: Enum.reverse(admins)}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp admin_attrs(email) do
    %{
      "email" => email,
      "name" => name_from_email(email),
      "company" => company_from_email(email)
    }
  end

  defp name_from_email(email) do
    email
    |> String.split("@", parts: 2)
    |> List.first()
  end

  defp company_from_email(email) do
    email
    |> String.split("@", parts: 2)
    |> List.last()
    |> String.split(".", parts: 2)
    |> List.first()
    |> humanize_domain()
  end

  defp humanize_domain(<<first::binary-size(1), rest::binary>>) do
    String.upcase(first) <> rest
  end

  defp optional_env(env, key) do
    case Map.get(env, key) do
      value when is_binary(value) ->
        value
        |> String.trim()
        |> empty_to_nil()

      _ ->
        nil
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp seed_error({:missing_env, key}), do: "environment variable #{key} is missing"
  defp seed_error(%Ecto.Changeset{}), do: "seed data is invalid"
  defp seed_error(reason), do: "seed failed: #{inspect(reason)}"
end
