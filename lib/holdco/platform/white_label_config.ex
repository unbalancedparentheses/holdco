defmodule Holdco.Platform.WhiteLabelConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "white_label_configs" do
    field :tenant_name, :string
    field :logo_url, :string
    field :favicon_url, :string
    field :primary_color, :string
    field :secondary_color, :string
    field :accent_color, :string
    field :font_family, :string
    field :custom_css, :string
    field :login_page_title, :string
    field :login_page_subtitle, :string
    field :footer_text, :string
    field :support_email, :string
    field :support_url, :string
    field :powered_by_visible, :boolean, default: true
    field :custom_domain, :string
    field :ssl_enabled, :boolean, default: true
    field :is_active, :boolean, default: false
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(white_label_config, attrs) do
    white_label_config
    |> cast(attrs, [
      :tenant_name, :logo_url, :favicon_url, :primary_color, :secondary_color,
      :accent_color, :font_family, :custom_css, :login_page_title,
      :login_page_subtitle, :footer_text, :support_email, :support_url,
      :powered_by_visible, :custom_domain, :ssl_enabled, :is_active, :notes
    ])
    |> validate_required([:tenant_name])
    |> validate_format(:primary_color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color (e.g. #FF0000)")
    |> validate_format(:secondary_color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color (e.g. #00FF00)")
    |> validate_format(:accent_color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color (e.g. #0000FF)")
  end
end
