defmodule GrowthPushRouter.AccountsTest do
  use GrowthPushRouter.DataCase, async: true

  alias GrowthPushRouter.Accounts
  alias GrowthPushRouter.Accounts.User

  doctest GrowthPushRouter.Accounts
  doctest GrowthPushRouter.Accounts.User

  describe "users" do
    setup do
      %{admin: %User{email: "admin@example.test"}}
    end

    test "admin? validates against the configured whitelist" do
      assert User.admin?(%User{email: "admin@example.test"})
      assert User.admin?(%User{email: "ADMIN@EXAMPLE.TEST"})
      refute User.admin?(%User{email: "client@example.com"})
    end

    test "CRUD operations reject non-admin users" do
      non_admin = %User{email: "client@example.com"}
      admin = %User{email: "admin@example.test"}

      {:ok, user} =
        Accounts.create_user(admin, %{
          "email" => "existing@example.com",
          "name" => "Existing"
        })

      assert {:error, :unauthorized} = Accounts.list_users(non_admin)
      assert {:error, :unauthorized} = Accounts.fetch_user(non_admin, user.id)

      assert {:error, :unauthorized} =
               Accounts.create_user(non_admin, %{
                 "email" => "other@example.com",
                 "name" => "Other"
               })

      assert {:error, :unauthorized} =
               Accounts.update_user(non_admin, user, %{"name" => "Updated"})

      assert {:error, :unauthorized} = Accounts.delete_user(non_admin, user)
    end

    test "admin creates users without a password", %{admin: admin} do
      assert {:ok, %User{} = user} =
               Accounts.create_user(admin, %{
                 "email" => "client@example.com",
                 "name" => "Client",
                 "company" => "Client Co"
               })

      refute User.password_set?(user)

      assert Accounts.authenticate_user("client@example.com", "anything") ==
               {:error, :password_not_set, user}
    end

    test "admin lists, reads, updates, and deletes users", %{admin: admin} do
      {:ok, user} =
        Accounts.create_user(admin, %{
          "email" => "client@example.com",
          "name" => "Client"
        })

      assert {:ok, [^user]} = Accounts.list_users(admin, search: "client")
      assert {:ok, ^user} = Accounts.fetch_user(admin, user.id)

      assert {:ok, updated_user} =
               Accounts.update_user(admin, user, %{
                 "email" => "client@example.com",
                 "name" => "Updated Client"
               })

      assert updated_user.name == "Updated Client"
      assert {:ok, _deleted_user} = Accounts.delete_user(admin, updated_user)
      assert Accounts.get_user(updated_user.id) == nil
    end

    test "normal users set their password once", %{admin: admin} do
      {:ok, user} =
        Accounts.create_user(admin, %{
          "email" => "client@example.com",
          "name" => "Client"
        })

      assert {:ok, updated_user} =
               Accounts.set_initial_password(user, %{
                 "password" => "strong-pass",
                 "password_confirmation" => "strong-pass"
               })

      assert User.password_set?(updated_user)

      assert {:ok, ^updated_user} =
               Accounts.authenticate_user("client@example.com", "strong-pass")

      assert {:error, :password_already_set} =
               Accounts.set_initial_password(updated_user, %{
                 "password" => "other-pass",
                 "password_confirmation" => "other-pass"
               })
    end

    test "admin reset clears the password so the user can set it again", %{admin: admin} do
      {:ok, user} =
        Accounts.create_user(admin, %{
          "email" => "client@example.com",
          "name" => "Client"
        })

      {:ok, user} =
        Accounts.set_initial_password(user, %{
          "password" => "strong-pass",
          "password_confirmation" => "strong-pass"
        })

      assert {:error, :unauthorized} =
               Accounts.reset_user_password(%User{email: "client@example.com"}, user)

      assert {:ok, reset_user} = Accounts.reset_user_password(admin, user)
      refute User.password_set?(reset_user)

      assert {:error, :password_not_set, ^reset_user} =
               Accounts.authenticate_user("client@example.com", "strong-pass")
    end
  end
end
