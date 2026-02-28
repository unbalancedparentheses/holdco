defmodule HoldcoWeb.ReportingTemplateLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Compliance
  alias Holdco.Compliance.ReportingTemplate

  @impl true
  def mount(_params, _session, socket) do
    templates = Compliance.list_reporting_templates()

    {:ok,
     assign(socket,
       page_title: "Reporting Templates",
       templates: templates,
       show_form: false,
       editing_item: nil,
       generated_report: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("close_report", _, socket) do
    {:noreply, assign(socket, generated_report: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    template = Compliance.get_reporting_template!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: template)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("generate", %{"id" => id}, socket) do
    case Compliance.generate_report(String.to_integer(id)) do
      {:ok, report} ->
        {:noreply, assign(socket, generated_report: report)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to generate report")}
    end
  end

  def handle_event("save", %{"reporting_template" => params}, socket) do
    case Compliance.create_reporting_template(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Template created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create template")}
    end
  end

  def handle_event("update", %{"reporting_template" => params}, socket) do
    template = socket.assigns.editing_item

    case Compliance.update_reporting_template(template, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Template updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update template")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    template = Compliance.get_reporting_template!(String.to_integer(id))

    case Compliance.delete_reporting_template(template) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Template deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete template")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Reporting Templates</h1>
          <p class="deck">CRS, FATCA, beneficial ownership registers, and regulatory reporting</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Template</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Templates</div>
        <div class="metric-value">{length(@templates)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@templates, & &1.is_active)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Templates</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Jurisdiction</th>
              <th>Frequency</th>
              <th>Due Date Formula</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for t <- @templates do %>
              <tr>
                <td class="td-name">{t.name}</td>
                <td><span class="tag tag-sky">{humanize_type(t.template_type)}</span></td>
                <td>{t.jurisdiction || "---"}</td>
                <td><span class="tag tag-jade">{humanize_frequency(t.frequency)}</span></td>
                <td class="td-mono">{t.due_date_formula || "---"}</td>
                <td>{if t.is_active, do: "Yes", else: "No"}</td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="generate" phx-value-id={t.id} class="btn btn-primary btn-sm">Generate</button>
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={t.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={t.id} class="btn btn-danger btn-sm" data-confirm="Delete this template?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @templates == [] do %>
          <div class="empty-state">
            <p>No reporting templates found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Template</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @generated_report do %>
      <div class="dialog-overlay" phx-click="close_report">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Generated Report: {@generated_report.template.name}</h3>
          </div>
          <div class="dialog-body">
            <p><strong>Type:</strong> {humanize_type(@generated_report.type)}</p>
            <p><strong>Jurisdiction:</strong> {@generated_report.jurisdiction || "Global"}</p>
            <p><strong>Generated:</strong> {Calendar.strftime(@generated_report.generated_at, "%Y-%m-%d %H:%M")}</p>
            <p><strong>Records:</strong> {length(@generated_report.records)}</p>
            <div class="form-actions">
              <button type="button" phx-click="close_report" class="btn btn-secondary">Close</button>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Template", else: "Add Template"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="reporting_template[name]" class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="reporting_template[template_type]" class="form-select" required>
                  <%= for t <- ReportingTemplate.template_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.template_type == t}>{humanize_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction</label>
                <input type="text" name="reporting_template[jurisdiction]" class="form-input"
                  value={if @editing_item, do: @editing_item.jurisdiction, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Frequency</label>
                <select name="reporting_template[frequency]" class="form-select">
                  <%= for f <- ReportingTemplate.frequencies() do %>
                    <option value={f} selected={@editing_item && @editing_item.frequency == f}>{humanize_frequency(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Due Date Formula</label>
                <input type="text" name="reporting_template[due_date_formula]" class="form-input"
                  placeholder="+90d" value={if @editing_item, do: @editing_item.due_date_formula, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Active</label>
                <select name="reporting_template[is_active]" class="form-select">
                  <option value="true" selected={!@editing_item || @editing_item.is_active}>Yes</option>
                  <option value="false" selected={@editing_item && !@editing_item.is_active}>No</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="reporting_template[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Template", else: "Add Template"}
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

  defp reload(socket) do
    templates = Compliance.list_reporting_templates()
    assign(socket, templates: templates)
  end

  defp humanize_type("crs"), do: "CRS"
  defp humanize_type("fatca"), do: "FATCA"
  defp humanize_type("bo_register"), do: "BO Register"
  defp humanize_type("aml_report"), do: "AML Report"
  defp humanize_type("regulatory_return"), do: "Regulatory Return"
  defp humanize_type("tax_return"), do: "Tax Return"
  defp humanize_type(other), do: other || "CRS"

  defp humanize_frequency("annual"), do: "Annual"
  defp humanize_frequency("semi_annual"), do: "Semi-Annual"
  defp humanize_frequency("quarterly"), do: "Quarterly"
  defp humanize_frequency("monthly"), do: "Monthly"
  defp humanize_frequency("ad_hoc"), do: "Ad Hoc"
  defp humanize_frequency(other), do: other || "Annual"
end
