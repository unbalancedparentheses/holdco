defmodule HoldcoWeb.BenchmarkLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    benchmarks = Analytics.list_benchmarks()
    comparisons = Analytics.list_benchmark_comparisons()
    companies = Corporate.list_companies()
    predefined = Analytics.predefined_benchmarks()

    {:ok,
     assign(socket,
       page_title: "Benchmarks",
       benchmarks: benchmarks,
       comparisons: comparisons,
       companies: companies,
       predefined: predefined,
       show_form: false,
       show_comparison_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: true, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("show_comparison_form", _, socket),
    do: {:noreply, assign(socket, show_comparison_form: true)}

  def handle_event("close_comparison_form", _, socket),
    do: {:noreply, assign(socket, show_comparison_form: false)}

  # Permission gating
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("calculate_comparison", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("add_predefined", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_comparison", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"benchmark" => params}, socket) do
    case Analytics.create_benchmark(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Benchmark created")
         |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create benchmark")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    benchmark = Analytics.get_benchmark!(String.to_integer(id))

    case Analytics.delete_benchmark(benchmark) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Benchmark deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete benchmark")}
    end
  end

  def handle_event("add_predefined", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    predef = Enum.at(socket.assigns.predefined, index)

    case Analytics.create_benchmark(predef) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "#{predef.name} added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add benchmark")}
    end
  end

  def handle_event("calculate_comparison", %{"comparison" => params}, socket) do
    benchmark_id = String.to_integer(params["benchmark_id"])
    company_id = if params["company_id"] == "", do: nil, else: String.to_integer(params["company_id"])
    period_start = Date.from_iso8601!(params["period_start"])
    period_end = Date.from_iso8601!(params["period_end"])

    case Analytics.calculate_comparison(benchmark_id, company_id, period_start, period_end) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> assign(show_comparison_form: false)
         |> put_flash(:info, "Comparison calculated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to calculate comparison")}
    end
  end

  def handle_event("delete_comparison", %{"id" => id}, socket) do
    comparison = Analytics.get_benchmark_comparison!(String.to_integer(id))

    case Analytics.delete_benchmark_comparison(comparison) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Comparison deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete comparison")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    assign(socket,
      benchmarks: Analytics.list_benchmarks(),
      comparisons: Analytics.list_benchmark_comparisons()
    )
  end

  defp format_decimal(nil), do: "---"
  defp format_decimal(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
  defp format_decimal(v), do: to_string(v)

  defp format_return(nil), do: "---"

  defp format_return(%Decimal{} = d) do
    rounded = Decimal.round(d, 2)
    str = Decimal.to_string(rounded)

    cond do
      Money.positive?(d) -> "+#{str}%"
      true -> "#{str}%"
    end
  end

  defp return_class(nil), do: ""
  defp return_class(%Decimal{} = d) do
    cond do
      Money.positive?(d) -> "num-positive"
      Money.negative?(d) -> "num-negative"
      true -> ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Benchmarks</h1>
          <p class="deck">Compare portfolio performance against market indices and custom benchmarks</p>
        </div>
        <div style="display: flex; gap: 0.5rem;">
          <%= if @can_write do %>
            <button class="btn btn-secondary" phx-click="show_comparison_form">New Comparison</button>
            <button class="btn btn-primary" phx-click="show_form">Add Benchmark</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Active Benchmarks</div>
        <div class="metric-value">{Enum.count(@benchmarks, & &1.is_active)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Comparisons</div>
        <div class="metric-value">{length(@comparisons)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Predefined Available</div>
        <div class="metric-value">{length(@predefined)}</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Benchmarks</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Ticker</th>
                <th>Active</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for b <- @benchmarks do %>
                <tr>
                  <td class="td-name">{b.name}</td>
                  <td><span class="tag tag-ink">{b.benchmark_type}</span></td>
                  <td class="td-mono">{b.ticker || "---"}</td>
                  <td>
                    <%= if b.is_active do %>
                      <span class="tag tag-jade">Active</span>
                    <% else %>
                      <span class="tag tag-ink">Inactive</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if @can_write do %>
                      <button phx-click="delete" phx-value-id={b.id} class="btn btn-danger btn-sm" data-confirm="Delete this benchmark?">Del</button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @benchmarks == [] do %>
            <div class="empty-state">
              <p>No benchmarks configured yet.</p>
              <p style="color: var(--muted); font-size: 0.9rem;">
                Add predefined market indices or create custom benchmarks to compare portfolio performance.
              </p>
            </div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Predefined Indices</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Ticker</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {p, idx} <- Enum.with_index(@predefined) do %>
                <tr>
                  <td class="td-name">{p.name}</td>
                  <td class="td-mono">{p.ticker}</td>
                  <td>
                    <%= if @can_write do %>
                      <button phx-click="add_predefined" phx-value-index={idx} class="btn btn-secondary btn-sm">Add</button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Comparison History</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Benchmark</th>
              <th>Company</th>
              <th>Period</th>
              <th class="th-num">Portfolio Return</th>
              <th class="th-num">Benchmark Return</th>
              <th class="th-num">Alpha</th>
              <th class="th-num">Tracking Error</th>
              <th class="th-num">Info Ratio</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @comparisons do %>
              <tr>
                <td class="td-name">{c.benchmark && c.benchmark.name || "---"}</td>
                <td>{c.company && c.company.name || "All"}</td>
                <td class="td-mono">{c.period_start} to {c.period_end}</td>
                <td class={"td-num #{return_class(c.portfolio_return)}"}>{format_return(c.portfolio_return)}</td>
                <td class={"td-num #{return_class(c.benchmark_return)}"}>{format_return(c.benchmark_return)}</td>
                <td class={"td-num #{return_class(c.alpha)}"}>{format_return(c.alpha)}</td>
                <td class="td-num">{format_decimal(c.tracking_error)}</td>
                <td class="td-num">{format_decimal(c.information_ratio)}</td>
                <td>
                  <%= if @can_write do %>
                    <button phx-click="delete_comparison" phx-value-id={c.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @comparisons == [] do %>
          <div class="empty-state">
            <p>No comparisons yet. Select a benchmark and date range to compare against your portfolio.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Add Benchmark Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add Custom Benchmark</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="benchmark[name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="benchmark[benchmark_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <option value="index">Index</option>
                  <option value="custom">Custom</option>
                  <option value="peer_group">Peer Group</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Ticker</label>
                <input type="text" name="benchmark[ticker]" class="form-input" placeholder="e.g. SPY" />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="benchmark[description]" class="form-input"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Benchmark</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%!-- New Comparison Modal --%>
    <%= if @show_comparison_form do %>
      <div class="dialog-overlay" phx-click="close_comparison_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Calculate Comparison</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="calculate_comparison">
              <div class="form-group">
                <label class="form-label">Benchmark *</label>
                <select name="comparison[benchmark_id]" class="form-select" required>
                  <option value="">Select benchmark</option>
                  <%= for b <- @benchmarks do %>
                    <option value={b.id}>{b.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="comparison[company_id]" class="form-select">
                  <option value="">All (Portfolio Level)</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Period Start *</label>
                <input type="date" name="comparison[period_start]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Period End *</label>
                <input type="date" name="comparison[period_end]" class="form-input" required />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Calculate</button>
                <button type="button" phx-click="close_comparison_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
