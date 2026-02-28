defmodule Holdco.Platform.WhiteLabelConfigTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "white_label_config CRUD" do
    test "get_white_label_config/0 returns nil when no config" do
      assert Platform.get_white_label_config() == nil
    end

    test "get_white_label_config/0 returns config when exists" do
      config = white_label_config_fixture()
      fetched = Platform.get_white_label_config()
      assert fetched.id == config.id
    end

    test "create_white_label_config/1 with valid data" do
      assert {:ok, config} =
               Platform.create_white_label_config(%{
                 tenant_name: "My Corp",
                 primary_color: "#FF0000",
                 secondary_color: "#00FF00",
                 accent_color: "#0000FF",
                 font_family: "Inter",
                 login_page_title: "Welcome",
                 login_page_subtitle: "Sign in to continue",
                 footer_text: "Powered by Holdco",
                 support_email: "support@example.com",
                 powered_by_visible: true,
                 is_active: true
               })

      assert config.tenant_name == "My Corp"
      assert config.primary_color == "#FF0000"
      assert config.font_family == "Inter"
      assert config.is_active == true
    end

    test "create_white_label_config/1 fails without tenant_name" do
      assert {:error, changeset} = Platform.create_white_label_config(%{})
      assert errors_on(changeset)[:tenant_name]
    end

    test "create_white_label_config/1 fails with invalid hex color" do
      assert {:error, changeset} =
               Platform.create_white_label_config(%{
                 tenant_name: "Test",
                 primary_color: "not-a-color"
               })

      assert errors_on(changeset)[:primary_color]
    end

    test "create_white_label_config/1 validates secondary color format" do
      assert {:error, changeset} =
               Platform.create_white_label_config(%{
                 tenant_name: "Test",
                 secondary_color: "blue"
               })

      assert errors_on(changeset)[:secondary_color]
    end

    test "create_white_label_config/1 validates accent color format" do
      assert {:error, changeset} =
               Platform.create_white_label_config(%{
                 tenant_name: "Test",
                 accent_color: "123456"
               })

      assert errors_on(changeset)[:accent_color]
    end

    test "update_white_label_config/2 with valid data" do
      config = white_label_config_fixture()

      assert {:ok, updated} =
               Platform.update_white_label_config(config, %{
                 tenant_name: "Updated Corp",
                 custom_css: "body { background: #000; }",
                 login_page_title: "New Title",
                 is_active: true
               })

      assert updated.tenant_name == "Updated Corp"
      assert updated.custom_css == "body { background: #000; }"
      assert updated.is_active == true
    end

    test "update_white_label_config/2 updates branding fields" do
      config = white_label_config_fixture()

      assert {:ok, updated} =
               Platform.update_white_label_config(config, %{
                 logo_url: "https://example.com/logo.png",
                 favicon_url: "https://example.com/favicon.ico",
                 support_url: "https://help.example.com"
               })

      assert updated.logo_url == "https://example.com/logo.png"
      assert updated.favicon_url == "https://example.com/favicon.ico"
      assert updated.support_url == "https://help.example.com"
    end

    test "reset_white_label_config/0 removes the config" do
      _config = white_label_config_fixture()
      assert {:ok, _} = Platform.reset_white_label_config()
      assert Platform.get_white_label_config() == nil
    end

    test "reset_white_label_config/0 returns ok when no config exists" do
      assert {:ok, nil} = Platform.reset_white_label_config()
    end

    test "create_white_label_config/1 with custom domain and ssl" do
      assert {:ok, config} =
               Platform.create_white_label_config(%{
                 tenant_name: "Domain Test",
                 custom_domain: "app.mycorp.com",
                 ssl_enabled: true
               })

      assert config.custom_domain == "app.mycorp.com"
      assert config.ssl_enabled == true
    end
  end
end
