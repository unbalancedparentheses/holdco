defmodule HoldcoWeb.ManagementReportsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate, Finance, Portfolio, Compliance}

  @available_sections [
    {"balance_sheet", "Balance Sheet"},
    {"income_statement", "Income Statement"},
    {"trial_balance", "Trial Balance"},
    {"cash_flow", "Cash Flow"},
    {"portfolio_nav", "Portfolio NAV"},
    {"compliance_summary", "Compliance Summary"},
    {"kpi_dashboard", "KPI Dashboard"},
    {"aging_report", "Aging Report"}
  ]

  @frequencies ~w(weekly monthly quarterly annually)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    templates = Analytics.list_report_templates()
    companies = Corporate.list_companies()
    today = Date.utc_today()

    {:ok,
     assign(socket,
       page_title: "Management Reports",
       templates: templates,
       companies: companies,
       available_sections: @available_sections,
       frequencies: @frequencies,
       show_form: false,
       editing_template: nil,
       # Form state
       form_name: "",
       form_sections: [],
       form_company_ids: [],
       form_date_from: Date.to_iso8601(%{today | month: 1, day: 1}),
       form_date_to: Date.to_iso8601(today),
       form_frequency: "monthly",
       # Generated report state
       generated_report: nil,
       generating: false
     )}
  end

  @impl true
  def handle_event("show_form", _, socket) do
    today = Date.utc_today()

    {:noreply,
     assign(socket,
       show_form: :add,
       editing_template: nil,
       form_name: "",
       form_sections: [],
       form_company_ids: [],
       form_date_from: Date.to_iso8601(%{today | month: 1, day: 1}),
       form_date_to: Date.to_iso8601(today),
       form_frequency: "monthly"
     )}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_template: nil)}
  end

  def handle_event("edit_template", %{"id" => id}, socket) do
    template = Analytics.get_report_template!(String.to_integer(id))
    sections = safe_decode_json(template.sections)
    company_ids = safe_decode_json(template.company_ids)

    {:noreply,
     assign(socket,
       show_form: :edit,
       editing_template: template,
       form_name: template.name,
       form_sections: sections,
       form_company_ids: Enum.map(company_ids, &to_string/1),
       form_date_from: template.date_from || "",
       form_date_to: template.date_to || "",
       form_frequency: template.frequency || "monthly"
     )}
  end

  def handle_event("toggle_section", %{"section" => section}, socket) do
    sections = socket.assigns.form_sections

    updated =
      if section in sections do
        List.delete(sections, section)
      else
        sections ++ [section]
      end

    {:noreply, assign(socket, form_sections: updated)}
  end

  def handle_event("toggle_company", %{"company-id" => company_id}, socket) do
    ids = socket.assigns.form_company_ids

    updated =
      if company_id in ids do
        List.delete(ids, company_id)
      else
        ids ++ [company_id]
      end

    {:noreply, assign(socket, form_company_ids: updated)}
  end

  def handle_event("update_form", params, socket) do
    {:noreply,
     assign(socket,
       form_name: params["name"] || socket.assigns.form_name,
       form_date_from: params["date_from"] || socket.assigns.form_date_from,
       form_date_to: params["date_to"] || socket.assigns.form_date_to,
       form_frequency: params["frequency"] || socket.assigns.form_frequency
     )}
  end

  def handle_event("save_template", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_template", _params, socket) do
    attrs = build_template_attrs(socket)

    case Analytics.create_report_template(attrs) do
      {:ok, _template} ->
        {:noreply,
         socket
         |> assign(
           templates: Analytics.list_report_templates(),
           show_form: false,
           editing_template: nil
         )
         |> put_flash(:info, "Report template created")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create template")}
    end
  end

  def handle_event("update_template", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update_template", _params, socket) do
    template = socket.assigns.editing_template
    attrs = build_template_attrs(socket)

    case Analytics.update_report_template(template, attrs) do
      {:ok, _template} ->
        {:noreply,
         socket
         |> assign(
           templates: Analytics.list_report_templates(),
           show_form: false,
           editing_template: nil
         )
         |> put_flash(:info, "Report template updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update template")}
    end
  end

  def handle_event("delete_template", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_template", %{"id" => id}, socket) do
    template = Analytics.get_report_template!(String.to_integer(id))

    case Analytics.delete_report_template(template) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(templates: Analytics.list_report_templates())
         |> put_flash(:info, "Template deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete template")}
    end
  end

  def handle_event("generate_report", %{"id" => id}, socket) do
    template = Analytics.get_report_template!(String.to_integer(id))
    sections = safe_decode_json(template.sections)
    company_ids = safe_decode_json(template.company_ids)
    date_from = template.date_from
    date_to = template.date_to

    report_data =
      Enum.flat_map(sections, fn section ->
        if company_ids == [] do
          [generate_section(section, nil, date_from, date_to)]
        else
          Enum.map(company_ids, fn cid ->
            company_id = if is_binary(cid), do: String.to_integer(cid), else: cid
            generate_section(section, company_id, date_from, date_to)
          end)
        end
      end)

    {:noreply,
     assign(socket,
       generated_report: %{
         name: template.name,
         generated_at: DateTime.utc_now(),
         sections: report_data
       }
     )}
  end

  def handle_event("generate_from_form", _params, socket) do
    sections = socket.assigns.form_sections
    company_ids = socket.assigns.form_company_ids
    date_from = socket.assigns.form_date_from
    date_to = socket.assigns.form_date_to

    report_data =
      Enum.flat_map(sections, fn section ->
        if company_ids == [] do
          [generate_section(section, nil, date_from, date_to)]
        else
          Enum.map(company_ids, fn cid ->
            company_id = if is_binary(cid), do: String.to_integer(cid), else: cid
            generate_section(section, company_id, date_from, date_to)
          end)
        end
      end)

    name = if socket.assigns.form_name == "", do: "Ad-hoc Report", else: socket.assigns.form_name

    {:noreply,
     assign(socket,
       generated_report: %{
         name: name,
         generated_at: DateTime.utc_now(),
         sections: report_data
       }
     )}
  end

  def handle_event("close_report", _, socket) do
    {:noreply, assign(socket, generated_report: nil)}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  @impl true
  def handle_info(_, socket) do
    {:noreply, assign(socket, templates: Analytics.list_report_templates())}
  end

  # --- Private helpers ---

  defp build_template_attrs(socket) do
    %{
      "name" => socket.assigns.form_name,
      "sections" => Jason.encode!(socket.assigns.form_sections),
      "company_ids" => Jason.encode!(socket.assigns.form_company_ids),
      "date_from" => socket.assigns.form_date_from,
      "date_to" => socket.assigns.form_date_to,
      "frequency" => socket.assigns.form_frequency,
      "user_id" =>
        if(socket.assigns[:current_scope],
          do: socket.assigns.current_scope.user.id,
          else: nil
        )
    }
  end

  defp generate_section(section, company_id, date_from, date_to) do
    data =
      case section do
        "balance_sheet" ->
          Finance.balance_sheet(company_id)

        "income_statement" ->
          Finance.income_statement(company_id, date_from, date_to)

        "trial_balance" ->
          Finance.trial_balance(company_id)

        "cash_flow" ->
          Finance.income_statement(company_id, date_from, date_to)

        "portfolio_nav" ->
          Portfolio.calculate_nav()

        "compliance_summary" ->
          %{
            deadlines: Compliance.list_tax_deadlines(company_id),
            filings: Compliance.list_regulatory_filings(company_id)
          }

        "kpi_dashboard" ->
          Analytics.list_kpis(company_id)

        "aging_report" ->
          Finance.trial_balance(company_id)

        _ ->
          nil
      end

    %{section: section, company_id: company_id, data: data}
  end

  defp safe_decode_json(nil), do: []
  defp safe_decode_json(""), do: []

  defp safe_decode_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  defp safe_decode_json(other) when is_list(other), do: other
  defp safe_decode_json(_), do: []

  defp section_label(key) do
    case List.keyfind(@available_sections, key, 0) do
      {_, label} -> label
      nil -> key
    end
  end

  defp frequency_label("weekly"), do: "Weekly"
  defp frequency_label("monthly"), do: "Monthly"
  defp frequency_label("quarterly"), do: "Quarterly"
  defp frequency_label("annually"), do: "Annually"
  defp frequency_label(other), do: other

  defp format_datetime(nil), do: ""

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) <> ".00" |> add_commas()
  defp format_number(_), do: "0.00"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int, dec] ->
        (int
         |> String.reverse()
         |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
         |> String.reverse()) <> "." <> dec

      [int] ->
        int |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end

  defp company_name(nil, _companies), do: "All Companies"

  defp company_name(company_id, companies) do
    id = if is_binary(company_id), do: String.to_integer(company_id), else: company_id

    case Enum.find(companies, fn c -> c.id == id end) do
      nil -> "Company ##{id}"
      c -> c.name
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Management Reports</h1>
          <p class="deck">Build custom report templates combining multiple data sections</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">New Template</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Saved Templates</div>
        <div class="metric-value">{length(@templates)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Available Sections</div>
        <div class="metric-value">{length(@available_sections)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Companies</div>
        <div class="metric-value">{length(@companies)}</div>
      </div>
    </div>

    <%!-- Generated Report View --%>
    <%= if @generated_report do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>{@generated_report.name}</h2>
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <span style="color: var(--muted); font-size: 0.85rem;">
              Generated {format_datetime(@generated_report.generated_at)}
            </span>
            <button class="btn btn-secondary" phx-click="close_report">Close Report</button>
          </div>
        </div>

        <%= for section_data <- @generated_report.sections do %>
          <div class="panel" style="margin-bottom: 1rem; padding: 1rem;">
            <h3 style="margin-bottom: 0.5rem; display: flex; gap: 0.5rem; align-items: center;">
              <span class="tag tag-jade">{section_label(section_data.section)}</span>
              <span style="font-size: 0.85rem; color: var(--muted);">
                {company_name(section_data.company_id, @companies)}
              </span>
            </h3>
            <.render_section_data section={section_data.section} data={section_data.data} />
          </div>
        <% end %>

        <%= if @generated_report.sections == [] do %>
          <div class="panel">
            <div class="empty-state">No sections selected for this report.</div>
          </div>
        <% end %>
      </div>
    <% end %>

    <%!-- Templates List --%>
    <div class="section">
      <div class="section-head"><h2>Report Templates</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Sections</th>
              <th>Companies</th>
              <th>Date Range</th>
              <th>Frequency</th>
              <th>Updated</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for t <- @templates do %>
              <% sections = safe_decode_json(t.sections) %>
              <% cids = safe_decode_json(t.company_ids) %>
              <tr>
                <td class="td-name">{t.name}</td>
                <td>
                  <div style="display: flex; gap: 0.25rem; flex-wrap: wrap;">
                    <%= for s <- sections do %>
                      <span class="tag tag-ink" style="font-size: 0.75rem;">{section_label(s)}</span>
                    <% end %>
                    <%= if sections == [] do %>
                      <span style="color: var(--muted);">None</span>
                    <% end %>
                  </div>
                </td>
                <td>
                  <%= if cids == [] do %>
                    <span style="color: var(--muted);">All</span>
                  <% else %>
                    {length(cids)} selected
                  <% end %>
                </td>
                <td class="td-mono">
                  <%= if t.date_from && t.date_to do %>
                    {t.date_from} to {t.date_to}
                  <% else %>
                    <span style="color: var(--muted);">---</span>
                  <% end %>
                </td>
                <td><span class="tag tag-lemon">{frequency_label(t.frequency)}</span></td>
                <td class="td-mono">{format_datetime(t.updated_at)}</td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button
                      phx-click="generate_report"
                      phx-value-id={t.id}
                      class="btn btn-primary btn-sm"
                    >
                      Generate
                    </button>
                    <%= if @can_write do %>
                      <button
                        phx-click="edit_template"
                        phx-value-id={t.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete_template"
                        phx-value-id={t.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this template?"
                      >
                        Del
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @templates == [] do %>
          <div class="empty-state">
            No report templates yet. Create one to build custom management reports combining
            balance sheets, income statements, compliance summaries, and more.
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Template Form Modal --%>
    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop" style="max-width: 640px;">
          <div class="modal-header">
            <h3>{if @show_form == :edit, do: "Edit Template", else: "New Report Template"}</h3>
          </div>
          <div class="modal-body">
            <form
              phx-change="update_form"
              phx-submit={if @show_form == :edit, do: "update_template", else: "save_template"}
            >
              <div class="form-group">
                <label class="form-label">Template Name *</label>
                <input
                  type="text"
                  name="name"
                  class="form-input"
                  value={@form_name}
                  placeholder="e.g. Monthly Board Report"
                  required
                />
              </div>

              <div class="form-group">
                <label class="form-label">Report Sections</label>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem;">
                  <%= for {key, label} <- @available_sections do %>
                    <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer; padding: 0.4rem; border: 1px solid var(--color-border); border-radius: 4px;">
                      <input
                        type="checkbox"
                        checked={key in @form_sections}
                        phx-click="toggle_section"
                        phx-value-section={key}
                      />
                      {label}
                    </label>
                  <% end %>
                </div>
              </div>

              <div class="form-group">
                <label class="form-label">Companies (leave unchecked for all)</label>
                <div style="max-height: 160px; overflow-y: auto; border: 1px solid var(--color-border); border-radius: 4px; padding: 0.5rem;">
                  <%= for c <- @companies do %>
                    <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer; padding: 0.25rem 0;">
                      <input
                        type="checkbox"
                        checked={to_string(c.id) in @form_company_ids}
                        phx-click="toggle_company"
                        phx-value-company-id={c.id}
                      />
                      {c.name}
                    </label>
                  <% end %>
                  <%= if @companies == [] do %>
                    <span style="color: var(--muted); font-size: 0.85rem;">No companies available</span>
                  <% end %>
                </div>
              </div>

              <div class="grid-2" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                <div class="form-group">
                  <label class="form-label">Date From</label>
                  <input type="date" name="date_from" class="form-input" value={@form_date_from} />
                </div>
                <div class="form-group">
                  <label class="form-label">Date To</label>
                  <input type="date" name="date_to" class="form-input" value={@form_date_to} />
                </div>
              </div>

              <div class="form-group">
                <label class="form-label">Frequency</label>
                <select name="frequency" class="form-select">
                  <%= for f <- @frequencies do %>
                    <option value={f} selected={f == @form_frequency}>{frequency_label(f)}</option>
                  <% end %>
                </select>
              </div>

              <div class="form-actions" style="display: flex; gap: 0.5rem; margin-top: 1rem;">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Template", else: "Save Template"}
                </button>
                <button
                  type="button"
                  phx-click="generate_from_form"
                  class="btn btn-secondary"
                >
                  Generate Report
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_section_data(%{section: "balance_sheet", data: data} = assigns) when is_map(data) do
    ~H"""
    <div class="metrics-strip" style="margin-bottom: 0.75rem;">
      <div class="metric-cell">
        <div class="metric-label">Total Assets</div>
        <div class="metric-value num-positive">${format_number(@data.total_assets)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Liabilities</div>
        <div class="metric-value num-negative">${format_number(@data.total_liabilities)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Equity</div>
        <div class="metric-value">${format_number(@data.total_equity)}</div>
      </div>
    </div>
    <table>
      <thead>
        <tr><th>Code</th><th>Account</th><th>Type</th><th class="th-num">Balance</th></tr>
      </thead>
      <tbody>
        <%= for a <- (@data.assets ++ @data.liabilities ++ @data.equity) do %>
          <tr>
            <td class="td-mono">{a.code}</td>
            <td>{a.name}</td>
            <td><span class={"badge badge-#{a.account_type}"}>{a.account_type}</span></td>
            <td class="td-num">{format_number(a.balance)}</td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp render_section_data(%{section: "income_statement", data: data} = assigns)
       when is_map(data) do
    ~H"""
    <div class="metrics-strip" style="margin-bottom: 0.75rem;">
      <div class="metric-cell">
        <div class="metric-label">Revenue</div>
        <div class="metric-value num-positive">${format_number(@data.total_revenue)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Expenses</div>
        <div class="metric-value num-negative">${format_number(@data.total_expenses)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Income</div>
        <div class={"metric-value #{if @data.net_income >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(@data.net_income)}
        </div>
      </div>
    </div>
    """
  end

  defp render_section_data(%{section: "trial_balance", data: data} = assigns)
       when is_list(data) do
    ~H"""
    <table>
      <thead>
        <tr><th>Code</th><th>Account</th><th class="th-num">Debit</th><th class="th-num">Credit</th><th class="th-num">Balance</th></tr>
      </thead>
      <tbody>
        <%= for row <- @data do %>
          <tr>
            <td class="td-mono">{row.code}</td>
            <td>{row.name}</td>
            <td class="td-num">{format_number(row.total_debit)}</td>
            <td class="td-num">{format_number(row.total_credit)}</td>
            <td class={"td-num #{if row.balance >= 0, do: "num-positive", else: "num-negative"}"}>{format_number(row.balance)}</td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp render_section_data(%{section: "portfolio_nav", data: data} = assigns)
       when is_map(data) do
    ~H"""
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total NAV</div>
        <div class="metric-value num-positive">${format_number(@data.total_nav)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Liquid</div>
        <div class="metric-value">${format_number(@data.liquid)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Illiquid</div>
        <div class="metric-value">${format_number(@data.illiquid)}</div>
      </div>
    </div>
    """
  end

  defp render_section_data(%{section: "compliance_summary", data: data} = assigns)
       when is_map(data) do
    ~H"""
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
      <div>
        <h4 style="margin-bottom: 0.5rem;">Tax Deadlines</h4>
        <table>
          <thead><tr><th>Type</th><th>Due Date</th><th>Status</th></tr></thead>
          <tbody>
            <%= for d <- (@data.deadlines || []) do %>
              <tr>
                <td>{d.tax_type}</td>
                <td class="td-mono">{d.due_date}</td>
                <td><span class={"tag #{deadline_tag(d.status)}"}>{d.status}</span></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <div>
        <h4 style="margin-bottom: 0.5rem;">Regulatory Filings</h4>
        <table>
          <thead><tr><th>Filing</th><th>Due Date</th><th>Status</th></tr></thead>
          <tbody>
            <%= for f <- (@data.filings || []) do %>
              <tr>
                <td>{f.filing_type}</td>
                <td class="td-mono">{f.due_date}</td>
                <td><span class={"tag #{deadline_tag(f.status)}"}>{f.status}</span></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_section_data(%{section: "kpi_dashboard", data: data} = assigns)
       when is_list(data) do
    ~H"""
    <table>
      <thead><tr><th>KPI</th><th>Unit</th><th>Target</th><th>Latest</th></tr></thead>
      <tbody>
        <%= for kpi <- @data do %>
          <tr>
            <td class="td-name">{kpi.name}</td>
            <td>{kpi.unit}</td>
            <td class="td-num">{format_number(kpi.target_value || 0)}</td>
            <td class="td-num">
              <% latest = List.first(kpi.snapshots || []) %>
              {if latest, do: format_number(latest.value), else: "---"}
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    <%= if @data == [] do %>
      <div class="empty-state">No KPIs defined.</div>
    <% end %>
    """
  end

  defp render_section_data(assigns) do
    ~H"""
    <div class="empty-state">No data available for this section.</div>
    """
  end

  defp deadline_tag("completed"), do: "tag-jade"
  defp deadline_tag("filed"), do: "tag-jade"
  defp deadline_tag("pending"), do: "tag-lemon"
  defp deadline_tag("overdue"), do: "tag-crimson"
  defp deadline_tag(_), do: "tag-ink"
end
