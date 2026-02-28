defmodule HoldcoWeb.K1Live.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Fund.subscribe()
    companies = Corporate.list_companies()
    k1_reports = Fund.list_k1_reports()

    {:ok,
     assign(socket,
       page_title: "K-1 Reports",
       companies: companies,
       k1_reports: k1_reports,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       show_generate_form: false,
       selected_report: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    k1_reports = Fund.list_k1_reports(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       k1_reports: k1_reports,
       selected_report: nil
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("show_generate_form", _, socket) do
    {:noreply, assign(socket, show_generate_form: true)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, show_generate_form: false)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    k1 = Fund.get_k1_report!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: k1)}
  end

  def handle_event("select_report", %{"id" => id}, socket) do
    k1 = Fund.get_k1_report!(String.to_integer(id))
    {:noreply, assign(socket, selected_report: k1)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, selected_report: nil)}
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

  def handle_event("save", %{"k1_report" => params}, socket) do
    case Fund.create_k1_report(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "K-1 report created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create K-1 report")}
    end
  end

  def handle_event("update", %{"k1_report" => params}, socket) do
    k1 = socket.assigns.editing_item

    case Fund.update_k1_report(k1, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "K-1 report updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update K-1 report")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    k1 = Fund.get_k1_report!(String.to_integer(id))

    case Fund.delete_k1_report(k1) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_report && socket.assigns.selected_report.id == k1.id,
            do: nil,
            else: socket.assigns.selected_report

        {:noreply,
         reload(socket)
         |> put_flash(:info, "K-1 report deleted")
         |> assign(selected_report: selected)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete K-1 report")}
    end
  end

  def handle_event("generate", %{"generate" => params}, socket) do
    company_id = String.to_integer(params["company_id"])
    tax_year = String.to_integer(params["tax_year"])
    investor_name = params["investor_name"]

    case Fund.generate_k1(company_id, tax_year, investor_name) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "K-1 report generated for #{investor_name}")
         |> assign(show_generate_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to generate K-1 report")}
    end
  end

  def handle_event("finalize", %{"id" => id}, socket) do
    k1 = Fund.get_k1_report!(String.to_integer(id))

    case Fund.update_k1_report(k1, %{status: "final"}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "K-1 report finalized")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to finalize K-1 report")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket) when event in [:k1_reports_created, :k1_reports_updated, :k1_reports_deleted] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>K-1 Reports</h1>
          <p class="deck">Schedule K-1 partner tax reporting</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">All Companies</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_generate_form">Generate K-1</button>
            <button class="btn btn-secondary" phx-click="show_form">Manual K-1</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>K-1 Reports</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Tax Year</th>
              <th>Investor</th>
              <th>Company</th>
              <th class="th-num">Ordinary Income</th>
              <th class="th-num">LT Capital Gains</th>
              <th class="th-num">Total Distributions</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for k1 <- @k1_reports do %>
              <tr>
                <td class="td-mono">{k1.tax_year}</td>
                <td class="td-name">{k1.investor_name}</td>
                <td>
                  <%= if k1.company do %>
                    <.link navigate={~p"/companies/#{k1.company.id}"} class="td-link">{k1.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">${format_number(k1.ordinary_income)}</td>
                <td class="td-num">${format_number(k1.long_term_capital_gains)}</td>
                <td class="td-num">${format_number(k1.total_distributions)}</td>
                <td><span class={"tag #{k1_status_tag(k1.status)}"}>{k1.status}</span></td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="select_report" phx-value-id={k1.id} class="btn btn-secondary btn-sm">View</button>
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={k1.id} class="btn btn-secondary btn-sm">Edit</button>
                      <%= if k1.status in ["draft", "review"] do %>
                        <button phx-click="finalize" phx-value-id={k1.id} class="btn btn-primary btn-sm">Finalize</button>
                      <% end %>
                      <button phx-click="delete" phx-value-id={k1.id} class="btn btn-danger btn-sm" data-confirm="Delete this K-1?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @k1_reports == [] do %>
          <div class="empty-state">
            <p>No K-1 reports found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_generate_form">Generate First K-1</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @selected_report do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>K-1 Detail: {@selected_report.investor_name} - {@selected_report.tax_year}</h2>
          <button phx-click="close_detail" class="btn btn-secondary btn-sm">Close</button>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div class="grid-2">
            <div>
              <h3 style="margin-bottom: 0.5rem;">Income</h3>
              <table>
                <tbody>
                  <tr><td class="td-name">Ordinary Income</td><td class="td-num">${format_number(@selected_report.ordinary_income)}</td></tr>
                  <tr><td class="td-name">Short-Term Capital Gains</td><td class="td-num">${format_number(@selected_report.short_term_capital_gains)}</td></tr>
                  <tr><td class="td-name">Long-Term Capital Gains</td><td class="td-num">${format_number(@selected_report.long_term_capital_gains)}</td></tr>
                  <tr><td class="td-name">Tax-Exempt Income</td><td class="td-num">${format_number(@selected_report.tax_exempt_income)}</td></tr>
                </tbody>
              </table>
            </div>
            <div>
              <h3 style="margin-bottom: 0.5rem;">Deductions & Capital</h3>
              <table>
                <tbody>
                  <tr><td class="td-name">Section 179 Deduction</td><td class="td-num">${format_number(@selected_report.section_179_deduction)}</td></tr>
                  <tr><td class="td-name">Other Deductions</td><td class="td-num">${format_number(@selected_report.other_deductions)}</td></tr>
                  <tr><td class="td-name">Total Distributions</td><td class="td-num">${format_number(@selected_report.total_distributions)}</td></tr>
                  <tr><td class="td-name">Beginning Capital</td><td class="td-num">${format_number(@selected_report.beginning_capital)}</td></tr>
                  <tr><td class="td-name">Ending Capital</td><td class="td-num">${format_number(@selected_report.ending_capital)}</td></tr>
                </tbody>
              </table>
            </div>
          </div>
          <%= if @selected_report.notes do %>
            <div style="margin-top: 1rem; padding: 0.5rem; background: var(--surface); border-radius: 4px;">
              <strong>Notes:</strong> {@selected_report.notes}
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit K-1 Report", else: "New K-1 Report"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="k1_report[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tax Year *</label>
                <input type="number" name="k1_report[tax_year]" class="form-input" value={if @editing_item, do: @editing_item.tax_year, else: Date.utc_today().year} required />
              </div>
              <div class="form-group">
                <label class="form-label">Investor Name *</label>
                <input type="text" name="k1_report[investor_name]" class="form-input" value={if @editing_item, do: @editing_item.investor_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Ordinary Income</label>
                <input type="number" name="k1_report[ordinary_income]" class="form-input" step="any" value={if @editing_item, do: @editing_item.ordinary_income, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Short-Term Capital Gains</label>
                <input type="number" name="k1_report[short_term_capital_gains]" class="form-input" step="any" value={if @editing_item, do: @editing_item.short_term_capital_gains, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Long-Term Capital Gains</label>
                <input type="number" name="k1_report[long_term_capital_gains]" class="form-input" step="any" value={if @editing_item, do: @editing_item.long_term_capital_gains, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Total Distributions</label>
                <input type="number" name="k1_report[total_distributions]" class="form-input" step="any" value={if @editing_item, do: @editing_item.total_distributions, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="k1_report[status]" class="form-select">
                  <option value="draft" selected={!@editing_item || @editing_item.status == "draft"}>Draft</option>
                  <option value="review" selected={@editing_item && @editing_item.status == "review"}>Review</option>
                  <option value="final" selected={@editing_item && @editing_item.status == "final"}>Final</option>
                  <option value="filed" selected={@editing_item && @editing_item.status == "filed"}>Filed</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="k1_report[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Create"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_generate_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Generate K-1 from Distributions</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="generate">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="generate[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tax Year *</label>
                <input type="number" name="generate[tax_year]" class="form-input" value={Date.utc_today().year - 1} required />
              </div>
              <div class="form-group">
                <label class="form-label">Investor Name *</label>
                <input type="text" name="generate[investor_name]" class="form-input" required />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Generate K-1</button>
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
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    k1_reports = Fund.list_k1_reports(company_id)
    assign(socket, k1_reports: k1_reports)
  end

  defp k1_status_tag("final"), do: "tag-jade"
  defp k1_status_tag("filed"), do: "tag-jade"
  defp k1_status_tag("review"), do: "tag-lemon"
  defp k1_status_tag(_), do: "tag-sky"

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(nil), do: "0"
  defp format_number(_), do: "0"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int =
          int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()

        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end
end
