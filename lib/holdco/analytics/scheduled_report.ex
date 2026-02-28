defmodule Holdco.Analytics.ScheduledReport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scheduled_reports" do
    field :name, :string
    field :report_type, :string
    field :frequency, :string
    field :recipients, :string
    field :format, :string, default: "html"
    field :is_active, :boolean, default: true
    field :last_sent_at, :utc_datetime
    field :next_run_date, :string
    field :filters, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @report_types ~w(portfolio_summary financial_report compliance_report board_pack)
  @frequencies ~w(daily weekly monthly quarterly)
  @formats ~w(html csv)

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :name,
      :report_type,
      :frequency,
      :recipients,
      :format,
      :is_active,
      :last_sent_at,
      :next_run_date,
      :filters,
      :notes,
      :company_id
    ])
    |> validate_required([:name, :report_type, :frequency, :recipients])
    |> validate_inclusion(:report_type, @report_types)
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_inclusion(:format, @formats)
    |> maybe_set_next_run_date()
  end

  defp maybe_set_next_run_date(changeset) do
    if get_change(changeset, :next_run_date) do
      changeset
    else
      case {get_field(changeset, :next_run_date), get_change(changeset, :frequency)} do
        {nil, _} ->
          put_change(changeset, :next_run_date, Date.to_iso8601(Date.utc_today()))

        {_, nil} ->
          changeset

        _ ->
          changeset
      end
    end
  end

  def report_types, do: @report_types
  def frequencies, do: @frequencies
  def formats, do: @formats
end
