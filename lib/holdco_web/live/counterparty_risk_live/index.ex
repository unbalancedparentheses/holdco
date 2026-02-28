defmodule HoldcoWeb.CounterpartyRiskLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    exposures = Analytics.list_counterparty_exposures()
    companies = Corporate.list_companies()
    concentration = Analytics.concentration_analysis()

    {:ok,
     assign(socket,
       page_title: "Counterparty Risk",
       exposures: exposures,
       companies: companies,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       concentration: concentration
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
    exposures = Analytics.list_counterparty_exposures(company_id)
    concentration = Analytics.concentration_analysis(company_id)
    {:noreply, assign(socket, selected_company_id: id, exposures: exposures, concentration: concentration)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    exposure = Analytics.get_counterparty_exposure!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: exposure)}
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

  def handle_event("save", %{"exposure" => params}, socket) do
    case Analytics.create_counterparty_exposure(params) do
      {:ok, exposure} ->
        # Auto-calculate risk score
        score = Analytics.calculate_risk_score(exposure)
        Analytics.update_counterparty_exposure(exposure, %{risk_score: score})

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Counterparty exposure created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create counterparty exposure")}
    end
  end

  def handle_event("update", %{"exposure" => params}, socket) do
    exposure = socket.assigns.editing_item

    case Analytics.update_counterparty_exposure(exposure, params) do
      {:ok, updated} ->
        score = Analytics.calculate_risk_score(updated)
        Analytics.update_counterparty_exposure(updated, %{risk_score: score})

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Counterparty exposure updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update counterparty exposure")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    exposure = Analytics.get_counterparty_exposure!(String.to_integer(id))
    Analytics.delete_counterparty_exposure(exposure)

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Counterparty exposure deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    exposures = Analytics.list_counterparty_exposures(company_id)
    concentration = Analytics.concentration_analysis(company_id)
    assign(socket, exposures: exposures, concentration: concentration)
  end

  defp risk_color(score) do
    score_val = Holdco.Money.to_float(score)
    cond do
      score_val >= 70 -> "num-negative"
      score_val >= 40 -> "tag-lemon"
      true -> "num-positive"
    end
  end

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("watchlist"), do: "tag-lemon"
  defp status_tag("restricted"), do: "tag-crimson"
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
          <h1>Counterparty Risk</h1>
          <p class="deck">Monitor counterparty exposures, credit risk, and concentration</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Exposure</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <% total_exposure = @concentration.total_exposure %>
    <% avg_risk = if length(@exposures) > 0, do: Holdco.Money.round(Holdco.Money.div(Enum.reduce(@exposures, Decimal.new(0), fn e, acc -> Holdco.Money.add(acc, Holdco.Money.to_decimal(e.risk_score)) end), length(@exposures)), 1), else: Decimal.new(0) %>
    <% watchlist_count = Enum.count(@exposures, & &1.status == "watchlist") %>
    <% warning_count = length(@concentration.warnings) %>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Exposure</div>
        <div class="metric-value">{fmt(total_exposure)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Avg Risk Score</div>
        <div class={"metric-value #{risk_color(avg_risk)}"}>{fmt(avg_risk)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Watchlist</div>
        <div class="metric-value">{watchlist_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Concentration Warnings</div>
        <div class={"metric-value #{if warning_count > 0, do: "num-negative", else: ""}"}>{warning_count}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Counterparty Exposures</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Counterparty</th>
              <th>Type</th>
              <th class="th-num">Exposure</th>
              <th>Credit Rating</th>
              <th class="th-num">Utilization %</th>
              <th class="th-num">Risk Score</th>
              <th>Status</th>
              <th>Next Review</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for exp <- @exposures do %>
              <tr>
                <td class="td-name">{exp.counterparty_name}</td>
                <td><span class="tag tag-ink">{exp.counterparty_type || "---"}</span></td>
                <td class="td-num">{fmt(exp.exposure_amount)}</td>
                <td><span class="tag tag-ink">{exp.credit_rating || "NR"}</span></td>
                <td class="td-num">{fmt(exp.utilization_pct)}</td>
                <td class={"td-num #{risk_color(exp.risk_score)}"}>{fmt(exp.risk_score)}</td>
                <td><span class={"tag #{status_tag(exp.status)}"}>{exp.status}</span></td>
                <td class="td-mono">{exp.next_review_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={exp.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={exp.id} class="btn btn-danger btn-sm" data-confirm="Delete this exposure?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @exposures == [] do %>
          <div class="empty-state">
            <p>No counterparty exposures tracked yet.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add First Exposure</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @concentration.warnings != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Concentration Warnings</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <ul>
            <%= for warning <- @concentration.warnings do %>
              <li style="color: var(--danger); margin-bottom: 0.25rem;">{warning}</li>
            <% end %>
          </ul>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>Concentration by Type</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th class="th-num">Total Exposure</th>
              <th class="th-num">Count</th>
              <th class="th-num">% of Total</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <%= for ct <- @concentration.by_type do %>
              <tr>
                <td>{ct.type || "unspecified"}</td>
                <td class="td-num">{fmt(ct.total)}</td>
                <td class="td-num">{ct.count}</td>
                <td class="td-num">{fmt(ct.percentage)}%</td>
                <td>
                  <%= if ct.concentrated do %>
                    <span class="tag tag-crimson">Concentrated</span>
                  <% else %>
                    <span class="tag tag-jade">OK</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <%!-- Add/Edit Exposure Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Exposure", else: "Add Exposure"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Counterparty Name *</label>
                <input type="text" name="exposure[counterparty_name]" class="form-input"
                  value={if @editing_item, do: @editing_item.counterparty_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label>
                <select name="exposure[counterparty_type]" class="form-select">
                  <option value="">Select type</option>
                  <%= for t <- ~w(bank broker custodian borrower lender vendor insurer) do %>
                    <option value={t} selected={@editing_item && @editing_item.counterparty_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Exposure Amount</label>
                <input type="number" name="exposure[exposure_amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.exposure_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="exposure[currency]" class="form-input"
                  value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Credit Rating</label>
                <select name="exposure[credit_rating]" class="form-select">
                  <option value="">Select rating</option>
                  <%= for r <- ~w(AAA AA A BBB BB B CCC CC C D NR) do %>
                    <option value={r} selected={@editing_item && @editing_item.credit_rating == r}>{r}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Rating Agency</label>
                <input type="text" name="exposure[rating_agency]" class="form-input"
                  placeholder="S&P, Moody's, Fitch"
                  value={if @editing_item, do: @editing_item.rating_agency, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Max Exposure Limit</label>
                <input type="number" name="exposure[max_exposure_limit]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.max_exposure_limit, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Utilization %</label>
                <input type="number" name="exposure[utilization_pct]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.utilization_pct, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="exposure[status]" class="form-select">
                  <%= for s <- ~w(active inactive watchlist restricted) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Next Review Date</label>
                <input type="date" name="exposure[next_review_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.next_review_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="exposure[company_id]" class="form-select">
                  <option value="">-- No company --</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="exposure[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Exposure", else: "Add Exposure"}
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
