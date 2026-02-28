defmodule Holdco.Platform.SsoConfigTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "sso_configs CRUD" do
    test "list_sso_configs/0 returns all configs" do
      config = sso_config_fixture()
      assert Enum.any?(Platform.list_sso_configs(), &(&1.id == config.id))
    end

    test "get_sso_config!/1 returns the config" do
      config = sso_config_fixture()
      fetched = Platform.get_sso_config!(config.id)
      assert fetched.id == config.id
      assert fetched.name == config.name
    end

    test "get_sso_config!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_sso_config!(0)
      end
    end

    test "create_sso_config/1 with valid data" do
      assert {:ok, config} =
               Platform.create_sso_config(%{
                 name: "Okta SAML",
                 provider_type: "saml",
                 entity_id: "https://okta.example.com/entity",
                 sso_url: "https://okta.example.com/sso",
                 slo_url: "https://okta.example.com/slo"
               })

      assert config.name == "Okta SAML"
      assert config.provider_type == "saml"
      assert config.entity_id == "https://okta.example.com/entity"
      assert config.is_active == true
      assert config.auto_provision_users == false
    end

    test "create_sso_config/1 with all provider types" do
      for type <- ~w(saml oidc oauth2) do
        assert {:ok, config} =
                 Platform.create_sso_config(%{
                   name: "Provider #{type}",
                   provider_type: type
                 })

        assert config.provider_type == type
      end
    end

    test "create_sso_config/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_sso_config(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:provider_type]
    end

    test "create_sso_config/1 fails with invalid provider_type" do
      assert {:error, changeset} =
               Platform.create_sso_config(%{
                 name: "Bad Provider",
                 provider_type: "invalid"
               })

      assert errors_on(changeset)[:provider_type]
    end

    test "create_sso_config/1 with attribute mapping" do
      mapping = %{"email" => "mail", "name" => "displayName"}

      assert {:ok, config} =
               Platform.create_sso_config(%{
                 name: "SAML with mapping",
                 provider_type: "saml",
                 attribute_mapping: mapping
               })

      assert config.attribute_mapping == mapping
    end

    test "update_sso_config/2 with valid data" do
      config = sso_config_fixture()

      assert {:ok, updated} =
               Platform.update_sso_config(config, %{
                 name: "Updated Name",
                 sso_url: "https://new.example.com/sso",
                 auto_provision_users: true
               })

      assert updated.name == "Updated Name"
      assert updated.sso_url == "https://new.example.com/sso"
      assert updated.auto_provision_users == true
    end

    test "update_sso_config/2 with invalid provider_type" do
      config = sso_config_fixture()

      assert {:error, changeset} =
               Platform.update_sso_config(config, %{provider_type: "bad"})

      assert errors_on(changeset)[:provider_type]
    end

    test "delete_sso_config/1 removes the config" do
      config = sso_config_fixture()
      assert {:ok, _} = Platform.delete_sso_config(config)

      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_sso_config!(config.id)
      end
    end

    test "active_sso_configs/0 returns only active configs" do
      active = sso_config_fixture(%{is_active: true, name: "Active"})
      _inactive = sso_config_fixture(%{is_active: false, name: "Inactive"})

      results = Platform.active_sso_configs()
      assert Enum.any?(results, &(&1.id == active.id))
      refute Enum.any?(results, &(&1.is_active == false))
    end

    test "get_sso_config_by_provider/1 returns config for provider" do
      config = sso_config_fixture(%{provider_type: "oidc", is_active: true})

      found = Platform.get_sso_config_by_provider("oidc")
      assert found.id == config.id
    end

    test "get_sso_config_by_provider/1 returns nil for missing provider" do
      assert Platform.get_sso_config_by_provider("nonexistent") == nil
    end

    test "create_sso_config/1 with client credentials" do
      assert {:ok, config} =
               Platform.create_sso_config(%{
                 name: "OAuth2 App",
                 provider_type: "oauth2",
                 client_id: "client123",
                 client_secret_encrypted: "encrypted_secret",
                 scopes: "openid profile email"
               })

      assert config.client_id == "client123"
      assert config.scopes == "openid profile email"
    end

    test "create_sso_config/1 with notes and default_role" do
      assert {:ok, config} =
               Platform.create_sso_config(%{
                 name: "Full Config",
                 provider_type: "saml",
                 default_role: "viewer",
                 notes: "Production SAML config"
               })

      assert config.default_role == "viewer"
      assert config.notes == "Production SAML config"
    end
  end
end
