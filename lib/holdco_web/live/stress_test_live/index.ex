defmodule HoldcoWeb.StressTestLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Analytics

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    stress_tests = Analytics.list_stress_tests()
    scenarios = Analytics.predefined_scenarios()

    {:ok,
     assign(socket,
       page_title: "Stress Testing",
       stress_tests: stress_tests,
       scenarios: scenarios,
       show_form: false,
       show_results: nil,
       custom_shocks: [],
       form_name: "",
       form_description: "",
       form_shocks: %{}
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply,
     assign(socket,
       show_form: true,
       form_name: "",
       form_description: "",
       form_shocks: %{},
       custom_shocks: []
     )}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  def handle_event("apply_scenario", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    scenario = Enum.at(socket.assigns.scenarios, index)

    shocks =
      scenario.shocks
      |> Enum.map(fn {k, v} -> {k, to_string(v)} end)
      |> Enum.into(%{})

    custom =
      Enum.map(shocks, fn {k, v} -> %{"key" => k, "value" => v} end)

    {:noreply,
     assign(socket,
       form_name: scenario.name,
       form_shocks: shocks,
       custom_shocks: custom
     )}
  end

  def handle_event("add_shock", _, socket) do
    custom = socket.assigns.custom_shocks ++ [%{"key" => "", "value" => ""}]
    {:noreply, assign(socket, custom_shocks: custom)}
  end

  def handle_event("remove_shock", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    custom = List.delete_at(socket.assigns.custom_shocks, index)
    shocks = build_shocks_map(custom)
    {:noreply, assign(socket, custom_shocks: custom, form_shocks: shocks)}
  end

  def handle_event("update_shock", params, socket) do
    index = String.to_integer(params["index"])
    field = params["field"]
    value = params["value"]

    custom =
      List.update_at(socket.assigns.custom_shocks, index, fn shock ->
        Map.put(shock, field, value)
      end)

    shocks = build_shocks_map(custom)
    {:noreply, assign(socket, custom_shocks: custom, form_shocks: shocks)}
  end

  # Permission gating
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("run", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"stress_test" => params}, socket) do
    shocks = build_shocks_map(socket.assigns.custom_shocks)

    attrs =
      params
      |> Map.put("shocks", shocks)

    case Analytics.create_stress_test(attrs) do
      {:ok, _st} ->
        {:noreply,
         reload(socket)
         |> assign(show_form: false)
         |> put_flash(:info, "Stress test created")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create stress test")}
    end
  end

  def handle_event("run", %{"id" => id}, socket) do
    st = Analytics.get_stress_test!(String.to_integer(id))

    case Analytics.run_stress_test(st) do
      {:ok, updated_st} ->
        {:noreply,
         reload(socket)
         |> assign(show_results: updated_st.id)
         |> put_flash(:info, "Stress test completed")}

      {:error, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:error, "Stress test failed")}
    end
  end

  def handle_event("show_results", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_results: String.to_integer(id))}
  end

  def handle_event("close_results", _, socket) do
    {:noreply, assign(socket, show_results: nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    st = Analytics.get_stress_test!(String.to_integer(id))
    Analytics.delete_stress_test(st)

    {:noreply,
     reload(socket)
     |> assign(show_results: nil)
     |> put_flash(:info, "Stress test deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    assign(socket, stress_tests: Analytics.list_stress_tests())
  end

  defp build_shocks_map(custom_shocks) do
    custom_shocks
    |> Enum.reject(fn s -> s["key"] == "" end)
    |> Enum.reduce(%{}, fn s, acc ->
      case Float.parse(s["value"] || "0") do
        {val, _} -> Map.put(acc, s["key"], val)
        :error -> acc
      end
    end)
  end

  defp status_badge("draft"), do: "tag-ink"
  defp status_badge("running"), do: "tag-lemon"
  defp status_badge("completed"), do: "tag-jade"
  defp status_badge("failed"), do: "tag-crimson"
  defp status_badge(_), do: "tag-ink"

  defp format_decimal(nil), do: "---"
  defp format_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, _} -> Decimal.round(d, 2) |> Decimal.to_string()
      :error -> val
    end
  end
  defp format_decimal(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
  defp format_decimal(val), do: to_string(val)

  defp format_pct(nil), do: "---"
  defp format_pct(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, _} -> "#{Decimal.round(d, 2) |> Decimal.to_string()}%"
      :error -> val
    end
  end
  defp format_pct(val), do: "#{format_decimal(val)}%"

  defp find_stress_test(stress_tests, id) do
    Enum.find(stress_tests, fn st -> st.id == id end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Stress Testing</h1>
          <p class="deck">Apply shocks to your portfolio and analyze impact</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">New Stress Test</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Stress Tests</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Status</th>
              <th>Shocks</th>
              <th>Run At</th>
              <th class="th-num">Impact</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for st <- @stress_tests do %>
              <tr>
                <td class="td-name">{st.name}</td>
                <td><span class={"tag #{status_badge(st.status)}"}>{st.status}</span></td>
                <td>
                  <%= for {key, val} <- st.shocks || %{} do %>
                    <span class="tag tag-ink" style="margin-right: 0.25rem;">
                      {key}: {format_pct(val)}
                    </span>
                  <% end %>
                </td>
                <td class="td-mono">
                  <%= if st.run_at do %>
                    {Calendar.strftime(st.run_at, "%Y-%m-%d %H:%M")}
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">
                  <%= if st.results && st.results["impact_pct"] do %>
                    <span class="num-negative">{format_pct(st.results["impact_pct"])}</span>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <%= if st.status in ~w(draft failed) and @can_write do %>
                      <button phx-click="run" phx-value-id={st.id} class="btn btn-primary btn-sm">Run</button>
                    <% end %>
                    <%= if st.status == "completed" do %>
                      <button phx-click="show_results" phx-value-id={st.id} class="btn btn-secondary btn-sm">Results</button>
                    <% end %>
                    <%= if @can_write do %>
                      <button phx-click="delete" phx-value-id={st.id} class="btn btn-danger btn-sm" data-confirm="Delete this stress test?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @stress_tests == [] do %>
          <div class="empty-state">
            <p>No stress tests created yet.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Create a stress test to see how shocks to asset prices, FX rates, or asset classes would affect your portfolio.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Create Your First Stress Test</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Results Modal --%>
    <%= if @show_results do %>
      <% st = find_stress_test(@stress_tests, @show_results) %>
      <%= if st && st.results do %>
        <div class="dialog-overlay" phx-click="close_results">
          <div class="dialog-panel" phx-click="noop" style="max-width: 900px;">
            <div class="dialog-header">
              <h3>Results: {st.name}</h3>
            </div>
            <div class="dialog-body">
              <div class="metrics-strip" style="margin-bottom: 1rem;">
                <div class="metric-cell">
                  <div class="metric-label">Original NAV</div>
                  <div class="metric-value">${format_decimal(st.results["original_nav"])}</div>
                </div>
                <div class="metric-cell">
                  <div class="metric-label">Stressed NAV</div>
                  <div class="metric-value">${format_decimal(st.results["stressed_nav"])}</div>
                </div>
                <div class="metric-cell">
                  <div class="metric-label">Impact</div>
                  <div class="metric-value num-negative">${format_decimal(st.results["impact"])}</div>
                </div>
                <div class="metric-cell">
                  <div class="metric-label">Impact %</div>
                  <div class="metric-value num-negative">{format_pct(st.results["impact_pct"])}</div>
                </div>
              </div>

              <%= if st.results["per_holding"] && st.results["per_holding"] != [] do %>
                <h4 style="margin-bottom: 0.5rem;">Per-Holding Breakdown</h4>
                <table>
                  <thead>
                    <tr>
                      <th>Asset</th>
                      <th>Ticker</th>
                      <th>Type</th>
                      <th class="th-num">Original</th>
                      <th class="th-num">Stressed</th>
                      <th class="th-num">Impact</th>
                      <th class="th-num">Shock</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for h <- st.results["per_holding"] do %>
                      <tr>
                        <td>{h["asset"]}</td>
                        <td class="td-mono">{h["ticker"] || "---"}</td>
                        <td><span class="tag tag-ink">{h["asset_type"]}</span></td>
                        <td class="td-num">${format_decimal(h["original_value"])}</td>
                        <td class="td-num">${format_decimal(h["stressed_value"])}</td>
                        <td class="td-num num-negative">${format_decimal(h["impact"])}</td>
                        <td class="td-num">{format_pct(h["shock_applied"])}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              <% else %>
                <div class="empty-state">No holdings were affected by these shocks.</div>
              <% end %>

              <div class="form-actions" style="margin-top: 1rem;">
                <button phx-click="close_results" class="btn btn-secondary">Close</button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    <% end %>

    <%!-- New Stress Test Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop" style="max-width: 700px;">
          <div class="dialog-header">
            <h3>New Stress Test</h3>
          </div>
          <div class="dialog-body">
            <div style="margin-bottom: 1rem;">
              <label class="form-label">Quick Scenarios</label>
              <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                <%= for {scenario, idx} <- Enum.with_index(@scenarios) do %>
                  <button
                    type="button"
                    class="btn btn-secondary btn-sm"
                    phx-click="apply_scenario"
                    phx-value-index={idx}
                  >
                    {scenario.name}
                  </button>
                <% end %>
              </div>
            </div>

            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="stress_test[name]" class="form-input" value={@form_name} required />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="stress_test[description]" class="form-input">{@form_description}</textarea>
              </div>

              <div class="form-group">
                <label class="form-label">Shocks</label>
                <p style="font-size: 0.8rem; color: #666; margin-bottom: 0.5rem;">
                  Enter ticker (BTC), asset type (equity, crypto), or FX pair (EUR/USD) with a shock percentage (e.g. -0.40 for -40%).
                </p>
                <%= for {shock, idx} <- Enum.with_index(@custom_shocks) do %>
                  <div style="display: flex; gap: 0.5rem; margin-bottom: 0.5rem; align-items: center;">
                    <input
                      type="text"
                      class="form-input"
                      placeholder="Key (e.g. BTC, equity, EUR/USD)"
                      value={shock["key"]}
                      phx-blur="update_shock"
                      phx-value-index={idx}
                      phx-value-field="key"
                      style="flex: 1;"
                    />
                    <input
                      type="text"
                      class="form-input"
                      placeholder="Shock (e.g. -0.40)"
                      value={shock["value"]}
                      phx-blur="update_shock"
                      phx-value-index={idx}
                      phx-value-field="value"
                      style="flex: 1;"
                    />
                    <button type="button" class="btn btn-danger btn-sm" phx-click="remove_shock" phx-value-index={idx}>X</button>
                  </div>
                <% end %>
                <button type="button" class="btn btn-secondary btn-sm" phx-click="add_shock">+ Add Shock</button>
              </div>

              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Create Stress Test</button>
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
