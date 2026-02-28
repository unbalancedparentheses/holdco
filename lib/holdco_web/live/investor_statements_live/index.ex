defmodule HoldcoWeb.InvestorStatementsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    statements = Fund.list_investor_statements()

    {:ok,
     assign(socket,
       page_title: "Investor Statements",
       companies: companies,
       statements: statements,
       selected_company_id: "",
       show_form: false,
       show_generate: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    opts = if company_id, do: [company_id: company_id], else: []
    statements = Fund.list_investor_statements(opts)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       statements: statements
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("show_generate", _, socket) do
    {:noreply, assign(socket, show_generate: true)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, show_generate: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    stmt = Fund.get_investor_statement!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: stmt)}
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

  def handle_event("generate", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"investor_statement" => params}, socket) do
    case Fund.create_investor_statement(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Investor statement created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create investor statement")}
    end
  end

  def handle_event("update", %{"investor_statement" => params}, socket) do
    stmt = socket.assigns.editing_item

    case Fund.update_investor_statement(stmt, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Investor statement updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update investor statement")}
    end
  end

  def handle_event("generate", %{"generate" => params}, socket) do
    company_id = String.to_integer(params["company_id"])
    investor_name = params["investor_name"]
    {:ok, period_start} = Date.from_iso8601(params["period_start"])
    {:ok, period_end} = Date.from_iso8601(params["period_end"])

    stmt_data = Fund.generate_investor_statement(company_id, investor_name, period_start, period_end)

    case Fund.create_investor_statement(stmt_data) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Investor statement generated")
         |> assign(show_generate: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to generate investor statement")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    stmt = Fund.get_investor_statement!(String.to_integer(id))

    case Fund.delete_investor_statement(stmt) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Investor statement deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete investor statement")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Investor Statements</h1>
          <p class="deck">Investor capital account statements and performance tracking</p>
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
            <button class="btn btn-secondary" phx-click="show_generate">Generate Statement</button>
            <button class="btn btn-primary" phx-click="show_form">Add Statement</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Statements</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Investor</th>
              <th>Company</th>
              <th>Period</th>
              <th class="th-num">Beginning</th>
              <th class="th-num">Contributions</th>
              <th class="th-num">Distributions</th>
              <th class="th-num">Ending</th>
              <th class="th-num">MOIC</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for stmt <- @statements do %>
              <tr>
                <td class="td-name">{stmt.investor_name}</td>
                <td>
                  <%= if stmt.company do %>
                    <.link navigate={~p"/companies/#{stmt.company.id}"} class="td-link">{stmt.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{stmt.period_start} to {stmt.period_end}</td>
                <td class="td-num">{format_decimal(stmt.beginning_balance)}</td>
                <td class="td-num">{format_decimal(stmt.contributions)}</td>
                <td class="td-num">{format_decimal(stmt.distributions)}</td>
                <td class="td-num">{format_decimal(stmt.ending_balance)}</td>
                <td class="td-num">{format_decimal(stmt.moic)}</td>
                <td><span class={"tag #{status_tag(stmt.status)}"}>{stmt.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={stmt.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={stmt.id} class="btn btn-danger btn-sm" data-confirm="Delete this statement?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @statements == [] do %>
          <div class="empty-state">
            <p>No investor statements found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Generate or create investor capital account statements.
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Statement", else: "Add Statement"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="investor_statement[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Investor Name *</label>
                <input type="text" name="investor_statement[investor_name]" class="form-input" value={if @editing_item, do: @editing_item.investor_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Period Start *</label>
                <input type="date" name="investor_statement[period_start]" class="form-input" value={if @editing_item, do: @editing_item.period_start, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Period End *</label>
                <input type="date" name="investor_statement[period_end]" class="form-input" value={if @editing_item, do: @editing_item.period_end, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Beginning Balance</label>
                <input type="number" name="investor_statement[beginning_balance]" class="form-input" step="any" value={if @editing_item, do: @editing_item.beginning_balance, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Contributions</label>
                <input type="number" name="investor_statement[contributions]" class="form-input" step="any" value={if @editing_item, do: @editing_item.contributions, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Distributions</label>
                <input type="number" name="investor_statement[distributions]" class="form-input" step="any" value={if @editing_item, do: @editing_item.distributions, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Ending Balance</label>
                <input type="number" name="investor_statement[ending_balance]" class="form-input" step="any" value={if @editing_item, do: @editing_item.ending_balance, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Ownership %</label>
                <input type="number" name="investor_statement[ownership_pct]" class="form-input" step="any" value={if @editing_item, do: @editing_item.ownership_pct, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">MOIC</label>
                <input type="number" name="investor_statement[moic]" class="form-input" step="any" value={if @editing_item, do: @editing_item.moic, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">IRR (%)</label>
                <input type="number" name="investor_statement[irr]" class="form-input" step="any" value={if @editing_item, do: @editing_item.irr, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="investor_statement[status]" class="form-select">
                  <%= for s <- ~w(draft review final sent) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="investor_statement[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Statement"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_generate do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Generate Investor Statement</h3>
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
                <label class="form-label">Investor Name *</label>
                <input type="text" name="generate[investor_name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Period Start *</label>
                <input type="date" name="generate[period_start]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Period End *</label>
                <input type="date" name="generate[period_end]" class="form-input" required />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Generate</button>
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

    opts = if company_id, do: [company_id: company_id], else: []
    statements = Fund.list_investor_statements(opts)
    assign(socket, statements: statements)
  end

  defp status_tag("draft"), do: "tag-slate"
  defp status_tag("review"), do: "tag-lemon"
  defp status_tag("final"), do: "tag-jade"
  defp status_tag("sent"), do: "tag-sky"
  defp status_tag(_), do: "tag-slate"

  defp format_decimal(nil), do: "---"
  defp format_decimal(%Decimal{} = d), do: d |> Decimal.round(2) |> Decimal.to_string()
  defp format_decimal(n) when is_number(n), do: Money.format(n)
  defp format_decimal(_), do: "---"
end
