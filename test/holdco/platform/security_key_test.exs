defmodule Holdco.Platform.SecurityKeyTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Platform

  describe "security_keys CRUD" do
    test "list_security_keys/1 returns keys for a user" do
      user = user_fixture()
      key = security_key_fixture(%{user: user})

      results = Platform.list_security_keys(user.id)
      assert Enum.any?(results, &(&1.id == key.id))
    end

    test "list_security_keys/1 does not return other users' keys" do
      user1 = user_fixture()
      user2 = user_fixture()
      _key1 = security_key_fixture(%{user: user1})
      key2 = security_key_fixture(%{user: user2})

      results = Platform.list_security_keys(user1.id)
      refute Enum.any?(results, &(&1.id == key2.id))
    end

    test "get_security_key!/1 returns the key" do
      key = security_key_fixture()
      fetched = Platform.get_security_key!(key.id)
      assert fetched.id == key.id
    end

    test "get_security_key!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_security_key!(0)
      end
    end

    test "register_security_key/1 with valid data" do
      user = user_fixture()

      assert {:ok, key} =
               Platform.register_security_key(%{
                 user_id: user.id,
                 name: "YubiKey 5",
                 credential_id: "cred_abc123",
                 public_key: "pk_xyz456",
                 aaguid: "aaguid_test",
                 transports: ["usb", "nfc"]
               })

      assert key.name == "YubiKey 5"
      assert key.credential_id == "cred_abc123"
      assert key.sign_count == 0
      assert key.is_active == true
      assert key.registered_at != nil
      assert key.transports == ["usb", "nfc"]
    end

    test "register_security_key/1 fails without required fields" do
      assert {:error, changeset} = Platform.register_security_key(%{})
      errors = errors_on(changeset)
      assert errors[:user_id]
      assert errors[:name]
      assert errors[:credential_id]
      assert errors[:public_key]
    end

    test "register_security_key/1 fails with negative sign_count" do
      user = user_fixture()

      assert {:error, changeset} =
               Platform.register_security_key(%{
                 user_id: user.id,
                 name: "Key",
                 credential_id: "cred_neg",
                 public_key: "pk_neg",
                 sign_count: -1
               })

      assert errors_on(changeset)[:sign_count]
    end

    test "update_security_key/2 with valid data" do
      key = security_key_fixture()

      assert {:ok, updated} =
               Platform.update_security_key(key, %{
                 name: "Renamed Key",
                 is_active: false,
                 notes: "Deactivated"
               })

      assert updated.name == "Renamed Key"
      assert updated.is_active == false
      assert updated.notes == "Deactivated"
    end

    test "delete_security_key/1 removes the key" do
      key = security_key_fixture()
      assert {:ok, _} = Platform.delete_security_key(key)

      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_security_key!(key.id)
      end
    end

    test "active_keys_for_user/1 returns only active keys" do
      user = user_fixture()
      active = security_key_fixture(%{user: user, is_active: true, name: "Active"})
      inactive = security_key_fixture(%{user: user, name: "Inactive"})
      {:ok, _} = Platform.update_security_key(inactive, %{is_active: false})

      results = Platform.active_keys_for_user(user.id)
      assert Enum.any?(results, &(&1.id == active.id))
      refute Enum.any?(results, &(&1.id == inactive.id))
    end

    test "increment_sign_count/1 increases sign_count by 1" do
      key = security_key_fixture()
      assert key.sign_count == 0

      assert {:ok, updated} = Platform.increment_sign_count(key)
      assert updated.sign_count == 1
      assert updated.last_used_at != nil
    end

    test "increment_sign_count/1 multiple times" do
      key = security_key_fixture()

      {:ok, key} = Platform.increment_sign_count(key)
      assert key.sign_count == 1

      {:ok, key} = Platform.increment_sign_count(key)
      assert key.sign_count == 2

      {:ok, key} = Platform.increment_sign_count(key)
      assert key.sign_count == 3
    end

    test "register_security_key/1 with notes" do
      user = user_fixture()

      assert {:ok, key} =
               Platform.register_security_key(%{
                 user_id: user.id,
                 name: "Key with notes",
                 credential_id: "cred_notes",
                 public_key: "pk_notes",
                 notes: "Primary authentication key"
               })

      assert key.notes == "Primary authentication key"
    end

    test "register_security_key/1 with aaguid" do
      user = user_fixture()

      assert {:ok, key} =
               Platform.register_security_key(%{
                 user_id: user.id,
                 name: "Key with AAGUID",
                 credential_id: "cred_aaguid",
                 public_key: "pk_aaguid",
                 aaguid: "test-aaguid-value"
               })

      assert key.aaguid == "test-aaguid-value"
    end

    test "register_security_key/1 sets default sign_count" do
      user = user_fixture()

      assert {:ok, key} =
               Platform.register_security_key(%{
                 user_id: user.id,
                 name: "Default Count Key",
                 credential_id: "cred_default_count",
                 public_key: "pk_default_count"
               })

      assert key.sign_count == 0
      assert key.is_active == true
    end

    test "list_security_keys/1 returns empty list for user with no keys" do
      user = user_fixture()
      assert Platform.list_security_keys(user.id) == []
    end
  end
end
