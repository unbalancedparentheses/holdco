defmodule HoldcoWeb.HealthScoreLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    scores = Analytics.list_health_scores()

    {:ok,
     assign(socket,
       page_title: "Financial Health Score",
       companies: companies,
       scores: scores,
       selected_company: nil,
       latest_score: nil,
       trend_scores: [],
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("select_company", %{"company_id" => company_id}, socket) do
    company_id = if company_id == "", do: nil, else: String.to_integer(company_id)

    if company_id do
      latest = Analytics.latest_health_score(company_id)
      trend = Analytics.health_score_trend(company_id)
      scores = Analytics.list_health_scores(company_id)
      {:noreply, assign(socket, selected_company: company_id, latest_score: latest, trend_scores: trend, scores: scores)}
    else
      scores = Analytics.list_health_scores()
      {:noreply, assign(socket, selected_company: nil, latest_score: nil, trend_scores: [], scores: scores)}
    end
  end

  def handle_event("recalculate", _, socket) do
    company_id = socket.assigns.selected_company

    if company_id do
      case Analytics.calculate_health_score(company_id) do
        {:ok, _score} ->
          latest = Analytics.latest_health_score(company_id)
          trend = Analytics.health_score_trend(company_id)
          scores = Analytics.list_health_scores(company_id)
          {:noreply, assign(socket, latest_score: latest, trend_scores: trend, scores: scores) |> put_flash(:info, "Health score recalculated")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to calculate health score")}
      end
    else
      {:noreply, put_flash(socket, :error, "Select a company first")}
    end
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"health_score" => params}, socket) do
    case Analytics.create_health_score(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Health score created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create health score")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    score = Analytics.get_health_score!(String.to_integer(id))

    case Analytics.delete_health_score(score) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Health score deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete health score")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Financial Health Score</h1>
          <p class="deck">Aggregated health score from multiple financial contexts</p>
        </div>
        <div style="display: flex; gap: 0.5rem;">
          <%= if @can_write do %>
            <button class="btn btn-secondary" phx-click="recalculate" disabled={@selected_company == nil}>Recalculate</button>
            <button class="btn btn-primary" phx-click="show_form">Add Score</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="panel" style="padding: 1rem;">
        <form phx-change="select_company">
          <select name="company_id" class="form-select">
            <option value="">All Companies</option>
            <%= for c <- @companies do %>
              <option value={c.id} selected={@selected_company == c.id}>{c.name}</option>
            <% end %>
          </select>
        </form>
      </div>
    </div>

    <%= if @latest_score do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Overall Score</div>
          <div class={"metric-value #{score_color(@latest_score.overall_score)}"}>{format_score(@latest_score.overall_score)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Liquidity</div>
          <div class="metric-value">{format_score(@latest_score.liquidity_score)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Profitability</div>
          <div class="metric-value">{format_score(@latest_score.profitability_score)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Compliance</div>
          <div class="metric-value">{format_score(@latest_score.compliance_score)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Governance</div>
          <div class="metric-value">{format_score(@latest_score.governance_score)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Risk</div>
          <div class="metric-value">{format_score(@latest_score.risk_score)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Operational</div>
          <div class="metric-value">{format_score(@latest_score.operational_score)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Trend</div>
          <div class="metric-value"><span class={"tag #{trend_tag(@latest_score.trend)}"}>{humanize(@latest_score.trend)}</span></div>
        </div>
      </div>
    <% end %>

    <%= if @trend_scores != [] do %>
      <div class="section">
        <div class="section-head"><h2>Trend (Last 12 Months)</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th><th>Overall</th><th>Liquidity</th><th>Profitability</th>
                <th>Compliance</th><th>Governance</th><th>Risk</th><th>Operational</th><th>Trend</th>
              </tr>
            </thead>
            <tbody>
              <%= for s <- @trend_scores do %>
                <tr>
                  <td class="td-mono">{s.score_date}</td>
                  <td class={"td-num #{score_color(s.overall_score)}"}>{format_score(s.overall_score)}</td>
                  <td class="td-num">{format_score(s.liquidity_score)}</td>
                  <td class="td-num">{format_score(s.profitability_score)}</td>
                  <td class="td-num">{format_score(s.compliance_score)}</td>
                  <td class="td-num">{format_score(s.governance_score)}</td>
                  <td class="td-num">{format_score(s.risk_score)}</td>
                  <td class="td-num">{format_score(s.operational_score)}</td>
                  <td><span class={"tag #{trend_tag(s.trend)}"}>{humanize(s.trend)}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Health Scores</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Date</th><th>Overall</th><th>Trend</th><th>Notes</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for s <- @scores do %>
              <tr>
                <td>{if s.company, do: s.company.name, else: "---"}</td>
                <td class="td-mono">{s.score_date}</td>
                <td class={"td-num #{score_color(s.overall_score)}"}>{format_score(s.overall_score)}</td>
                <td><span class={"tag #{trend_tag(s.trend)}"}>{humanize(s.trend)}</span></td>
                <td>{s.notes || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <button phx-click="delete" phx-value-id={s.id} class="btn btn-danger btn-sm" data-confirm="Delete this score?">Del</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @scores == [] do %>
          <div class="empty-state">
            <p>No health scores found. Select a company and click Recalculate.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add Health Score</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="health_score[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Score Date *</label>
                <input type="date" name="health_score[score_date]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Overall Score (0-100) *</label>
                <input type="number" name="health_score[overall_score]" class="form-input" step="0.1" min="0" max="100" required />
              </div>
              <div class="form-group">
                <label class="form-label">Liquidity Score</label>
                <input type="number" name="health_score[liquidity_score]" class="form-input" step="0.1" min="0" max="100" />
              </div>
              <div class="form-group">
                <label class="form-label">Profitability Score</label>
                <input type="number" name="health_score[profitability_score]" class="form-input" step="0.1" min="0" max="100" />
              </div>
              <div class="form-group">
                <label class="form-label">Compliance Score</label>
                <input type="number" name="health_score[compliance_score]" class="form-input" step="0.1" min="0" max="100" />
              </div>
              <div class="form-group">
                <label class="form-label">Governance Score</label>
                <input type="number" name="health_score[governance_score]" class="form-input" step="0.1" min="0" max="100" />
              </div>
              <div class="form-group">
                <label class="form-label">Risk Score</label>
                <input type="number" name="health_score[risk_score]" class="form-input" step="0.1" min="0" max="100" />
              </div>
              <div class="form-group">
                <label class="form-label">Operational Score</label>
                <input type="number" name="health_score[operational_score]" class="form-input" step="0.1" min="0" max="100" />
              </div>
              <div class="form-group">
                <label class="form-label">Trend</label>
                <select name="health_score[trend]" class="form-select">
                  <option value="stable">Stable</option>
                  <option value="improving">Improving</option>
                  <option value="declining">Declining</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="health_score[notes]" class="form-input"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Score</button>
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
    company_id = socket.assigns.selected_company
    scores = if company_id, do: Analytics.list_health_scores(company_id), else: Analytics.list_health_scores()
    latest = if company_id, do: Analytics.latest_health_score(company_id), else: nil
    trend = if company_id, do: Analytics.health_score_trend(company_id), else: []
    assign(socket, scores: scores, latest_score: latest, trend_scores: trend)
  end

  defp format_score(nil), do: "---"
  defp format_score(score), do: Decimal.to_string(Decimal.round(score, 1))

  defp score_color(nil), do: ""
  defp score_color(score) do
    val = Decimal.to_float(score)
    cond do
      val >= 75 -> "text-green"
      val >= 50 -> "text-yellow"
      true -> "text-red"
    end
  end

  defp humanize(str) when is_binary(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  defp humanize(nil), do: "---"

  defp trend_tag("improving"), do: "tag-jade"
  defp trend_tag("stable"), do: "tag-sky"
  defp trend_tag("declining"), do: "tag-lemon"
  defp trend_tag(_), do: ""
end
