defmodule Holdco.Repo.Migrations.CreateWhiteLabelConfigs do
  use Ecto.Migration

  def change do
    create table(:white_label_configs) do
      add :tenant_name, :string, null: false
      add :logo_url, :string
      add :favicon_url, :string
      add :primary_color, :string
      add :secondary_color, :string
      add :accent_color, :string
      add :font_family, :string
      add :custom_css, :text
      add :login_page_title, :string
      add :login_page_subtitle, :string
      add :footer_text, :string
      add :support_email, :string
      add :support_url, :string
      add :powered_by_visible, :boolean, default: true
      add :ssl_enabled, :boolean, default: true
      add :custom_domain, :string
      add :is_active, :boolean, default: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end
  end
end
