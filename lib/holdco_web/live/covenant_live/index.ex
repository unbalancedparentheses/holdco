defmodule HoldcoWeb.CovenantLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate, Finance}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    covenants = Analytics.list_loan_covenants()
    companies = Corporate.list_companies()
    liabilities = Finance.list_liabilities()

    {:ok,
     assign(socket,
       page_title: "Loan Covenants",
       covenants: covenants,
       companies: companies,
       liabilities: liabilities,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    covenants = Analytics.list_loan_covenants(company_id)
    {:noreply, assign(socket, selected_company_id: id, covenants: covenants)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    covenant = Analytics.get_loan_covenant!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: covenant)}
  end

  # Permission gating
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("check_all", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"covenant" => params}, socket) do
    case Analytics.create_loan_covenant(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Covenant created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create covenant")}
    end
  end

  def handle_event("update", %{"covenant" => params}, socket) do
    covenant = socket.assigns.editing_item

    case Analytics.update_loan_covenant(covenant, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Covenant updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update covenant")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    covenant = Analytics.get_loan_covenant!(String.to_integer(id))
    Analytics.delete_loan_covenant(covenant)

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Covenant deleted")}
  end

  def handle_event("check_all", _params, socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    Analytics.check_all_covenants(company_id)

    {:noreply,
     reload(socket)
     |> put_flash(:info, "All covenants checked")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    assign(socket, covenants: Analytics.list_loan_covenants(company_id))
  end

  defp status_tag("compliant"), do: "tag-jade"
  defp status_tag("warning"), do: "tag-lemon"
  defp status_tag("breached"), do: "tag-crimson"
  defp status_tag("waived"), do: "tag-ink"
  defp status_tag(_), do: "tag-ink"

  defp fmt(nil), do: "---"
  defp fmt(%Decimal{} = d), do: Holdco.Money.format(d, 2)
  defp fmt(v), do: Holdco.Money.format(v, 2)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Loan Covenants</h1>
          <p class="deck">Monitor loan covenant compliance across all entities</p>
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
            <button class="btn btn-secondary" phx-click="check_all">Check All</button>
            <button class="btn btn-primary" phx-click="show_form">Add Covenant</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <% compliant_count = Enum.count(@covenants, & &1.status == "compliant") %>
    <% warning_count = Enum.count(@covenants, & &1.status == "warning") %>
    <% breached_count = Enum.count(@covenants, & &1.status == "breached") %>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Covenants</div>
        <div class="metric-value">{length(@covenants)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Compliant</div>
        <div class="metric-value num-positive">{compliant_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Warning</div>
        <div class="metric-value">{warning_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Breached</div>
        <div class="metric-value num-negative">{breached_count}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Covenants</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Metric</th>
              <th class="th-num">Threshold</th>
              <th class="th-num">Current Value</th>
              <th>Comparison</th>
              <th>Status</th>
              <th>Frequency</th>
              <th>Next Measurement</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for cov <- @covenants do %>
              <tr>
                <td class="td-name">{cov.name}</td>
                <td><span class="tag tag-ink">{cov.covenant_type}</span></td>
                <td>{cov.metric || "---"}</td>
                <td class="td-num">{fmt(cov.threshold)}</td>
                <td class="td-num">{fmt(cov.current_value)}</td>
                <td>{cov.comparison || "---"}</td>
                <td><span class={"tag #{status_tag(cov.status)}"}>{cov.status}</span></td>
                <td>{cov.measurement_frequency}</td>
                <td class="td-mono">{cov.next_measurement_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={cov.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={cov.id} class="btn btn-danger btn-sm" data-confirm="Delete this covenant?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @covenants == [] do %>
          <div class="empty-state">
            <p>No loan covenants tracked yet.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add First Covenant</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Add/Edit Covenant Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Covenant", else: "Add Covenant"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="covenant[name]" class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Covenant Type *</label>
                <select name="covenant[covenant_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(financial reporting affirmative negative) do %>
                    <option value={t} selected={@editing_item && @editing_item.covenant_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Metric</label>
                <select name="covenant[metric]" class="form-select">
                  <option value="">Select metric</option>
                  <%= for m <- ~w(debt_to_equity current_ratio interest_coverage min_cash max_leverage) do %>
                    <option value={m} selected={@editing_item && @editing_item.metric == m}>{String.replace(m, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Threshold</label>
                <input type="number" name="covenant[threshold]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.threshold, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Comparison</label>
                <select name="covenant[comparison]" class="form-select">
                  <option value="">Select comparison</option>
                  <%= for c <- ~w(above below between) do %>
                    <option value={c} selected={@editing_item && @editing_item.comparison == c}>{c}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Upper Bound (for "between")</label>
                <input type="number" name="covenant[upper_bound]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.upper_bound, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Measurement Frequency</label>
                <select name="covenant[measurement_frequency]" class="form-select">
                  <%= for f <- ~w(monthly quarterly annually) do %>
                    <option value={f} selected={@editing_item && @editing_item.measurement_frequency == f}>{f}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="covenant[status]" class="form-select">
                  <%= for s <- ~w(compliant warning breached waived) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Liability</label>
                <select name="covenant[liability_id]" class="form-select">
                  <option value="">-- No liability --</option>
                  <%= for l <- @liabilities do %>
                    <option value={l.id} selected={@editing_item && @editing_item.liability_id == l.id}>{l.creditor} ({l.liability_type})</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="covenant[company_id]" class="form-select">
                  <option value="">-- No company --</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Next Measurement Date</label>
                <input type="date" name="covenant[next_measurement_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.next_measurement_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="covenant[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="covenant[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Covenant", else: "Add Covenant"}
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
end
