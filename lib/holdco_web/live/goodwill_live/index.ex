defmodule HoldcoWeb.GoodwillLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    goodwill_list = Finance.list_goodwill()
    metrics = compute_metrics(goodwill_list)

    {:ok,
     assign(socket,
       page_title: "Goodwill & Impairment",
       companies: companies,
       goodwill_list: goodwill_list,
       metrics: metrics,
       selected_company_id: "",
       selected_goodwill: nil,
       impairment_tests: [],
       show_form: false,
       show_test_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    goodwill_list = Finance.list_goodwill(company_id)
    metrics = compute_metrics(goodwill_list)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       goodwill_list: goodwill_list,
       metrics: metrics,
       selected_goodwill: nil,
       impairment_tests: []
     )}
  end

  def handle_event("select_goodwill", %{"id" => id}, socket) do
    gw = Finance.get_goodwill!(String.to_integer(id))
    tests = Finance.list_impairment_tests(gw.id)
    {:noreply, assign(socket, selected_goodwill: gw, impairment_tests: tests)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, selected_goodwill: nil, impairment_tests: [])}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("show_test_form", _, socket) do
    {:noreply, assign(socket, show_test_form: true)}
  end

  def handle_event("close_test_form", _, socket) do
    {:noreply, assign(socket, show_test_form: false)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    gw = Finance.get_goodwill!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: gw)}
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

  def handle_event("run_test", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"goodwill" => params}, socket) do
    case Finance.create_goodwill(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Goodwill record created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create goodwill record")}
    end
  end

  def handle_event("update", %{"goodwill" => params}, socket) do
    gw = socket.assigns.editing_item

    case Finance.update_goodwill(gw, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Goodwill record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update goodwill record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    gw = Finance.get_goodwill!(String.to_integer(id))

    case Finance.delete_goodwill(gw) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_goodwill && socket.assigns.selected_goodwill.id == gw.id,
            do: nil,
            else: socket.assigns.selected_goodwill

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Goodwill record deleted")
         |> assign(
           selected_goodwill: selected,
           impairment_tests: if(selected, do: socket.assigns.impairment_tests, else: [])
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete goodwill record")}
    end
  end

  def handle_event("run_test", %{"impairment_test" => params}, socket) do
    gw = socket.assigns.selected_goodwill

    case Finance.run_impairment_test(gw.id, params) do
      {:ok, %{test: _test, goodwill: updated_gw}} ->
        tests = Finance.list_impairment_tests(updated_gw.id)

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Impairment test completed")
         |> assign(
           selected_goodwill: Finance.get_goodwill!(updated_gw.id),
           impairment_tests: tests,
           show_test_form: false
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to run impairment test")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Goodwill & Impairment Testing</h1>
          <p class="deck">Track goodwill from acquisitions and perform ASC 350 / IAS 36 impairment testing</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Goodwill</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Original Amount</div>
        <div class="metric-value">${format_number(@metrics.total_original)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Carrying Value</div>
        <div class="metric-value">${format_number(@metrics.total_carrying)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Impairment</div>
        <div class="metric-value num-negative">${format_number(@metrics.total_impairment)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Records</div>
        <div class="metric-value">{@metrics.active_count}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Goodwill Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Acquisition</th>
              <th>Company</th>
              <th>Reporting Unit</th>
              <th class="th-num">Original Amount</th>
              <th class="th-num">Accumulated Impairment</th>
              <th class="th-num">Carrying Value</th>
              <th>Status</th>
              <th class="td-mono">Last Test</th>
              <th class="td-mono">Next Test</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for gw <- @goodwill_list do %>
              <tr>
                <td>
                  <button
                    phx-click="select_goodwill"
                    phx-value-id={gw.id}
                    class="td-link td-name"
                    style="background: none; border: none; cursor: pointer; padding: 0; font: inherit; text-align: left;"
                  >
                    {gw.acquisition_name}
                  </button>
                </td>
                <td>{if gw.company, do: gw.company.name, else: "---"}</td>
                <td>{gw.reporting_unit || "---"}</td>
                <td class="td-num">{format_number(gw.original_amount)}</td>
                <td class="td-num num-negative">{format_number(gw.accumulated_impairment)}</td>
                <td class="td-num">{format_number(gw.carrying_value)}</td>
                <td><span class={"tag #{status_tag(gw.status)}"}>{humanize_type(gw.status)}</span></td>
                <td class="td-mono">{gw.last_test_date || "---"}</td>
                <td class="td-mono">{gw.next_test_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={gw.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={gw.id} class="btn btn-danger btn-sm" data-confirm="Delete this goodwill record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @goodwill_list == [] do %>
          <div class="empty-state">
            <p>No goodwill records found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add First Goodwill Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @selected_goodwill do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Impairment Tests: {@selected_goodwill.acquisition_name}</h2>
          <div style="display: flex; gap: 0.5rem;">
            <%= if @can_write do %>
              <button phx-click="show_test_form" class="btn btn-primary btn-sm">Run Test</button>
            <% end %>
            <button phx-click="close_detail" class="btn btn-secondary btn-sm">Close</button>
          </div>
        </div>
        <div class="panel" style="padding: 1rem; margin-bottom: 1rem;">
          <div class="grid-2">
            <div>
              <div style="font-size: 0.85rem; color: #888; margin-bottom: 0.25rem;">Acquisition Date</div>
              <div style="font-weight: 600;">{@selected_goodwill.acquisition_date || "---"}</div>
            </div>
            <div>
              <div style="font-size: 0.85rem; color: #888; margin-bottom: 0.25rem;">Current Carrying Value</div>
              <div style="font-weight: 600;">${format_number(@selected_goodwill.carrying_value)}</div>
            </div>
          </div>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th class="td-mono">Test Date</th>
                <th>Method</th>
                <th class="th-num">Fair Value</th>
                <th class="th-num">Carrying Amount</th>
                <th class="th-num">Impairment</th>
                <th>Result</th>
                <th class="th-num">Discount Rate</th>
                <th class="th-num">Growth Rate</th>
              </tr>
            </thead>
            <tbody>
              <%= for test <- @impairment_tests do %>
                <tr>
                  <td class="td-mono">{test.test_date}</td>
                  <td><span class="tag tag-jade">{humanize_type(test.method)}</span></td>
                  <td class="td-num">{format_number(test.fair_value)}</td>
                  <td class="td-num">{format_number(test.carrying_amount)}</td>
                  <td class="td-num num-negative">{format_number(test.impairment_amount)}</td>
                  <td>
                    <span class={"tag #{if test.result == "no_impairment", do: "tag-jade", else: "tag-rose"}"}>
                      {humanize_type(test.result)}
                    </span>
                  </td>
                  <td class="td-num">{format_rate(test.discount_rate)}</td>
                  <td class="td-num">{format_rate(test.growth_rate)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @impairment_tests == [] do %>
            <div class="empty-state">No impairment tests have been run for this goodwill record.</div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_test_form && @selected_goodwill do %>
      <div class="dialog-overlay" phx-click="close_test_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Run Impairment Test: {@selected_goodwill.acquisition_name}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="run_test">
              <div class="form-group">
                <label class="form-label">Fair Value *</label>
                <input type="number" name="impairment_test[fair_value]" class="form-input" step="any" required />
              </div>
              <div class="form-group">
                <label class="form-label">Test Date</label>
                <input type="date" name="impairment_test[test_date]" class="form-input" value={Date.to_iso8601(Date.utc_today())} />
              </div>
              <div class="form-group">
                <label class="form-label">Method</label>
                <select name="impairment_test[method]" class="form-select">
                  <%= for m <- ~w(income_approach market_approach cost_approach) do %>
                    <option value={m}>{humanize_type(m)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Discount Rate (%)</label>
                <input type="number" name="impairment_test[discount_rate]" class="form-input" step="any" />
              </div>
              <div class="form-group">
                <label class="form-label">Growth Rate (%)</label>
                <input type="number" name="impairment_test[growth_rate]" class="form-input" step="any" />
              </div>
              <div class="form-group">
                <label class="form-label">Assumptions</label>
                <textarea name="impairment_test[assumptions]" class="form-input"></textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="impairment_test[notes]" class="form-input"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Run Test</button>
                <button type="button" phx-click="close_test_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Goodwill", else: "Add Goodwill"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="goodwill[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Acquisition Name *</label>
                <input type="text" name="goodwill[acquisition_name]" class="form-input" value={if @editing_item, do: @editing_item.acquisition_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Acquisition Date</label>
                <input type="date" name="goodwill[acquisition_date]" class="form-input" value={if @editing_item, do: @editing_item.acquisition_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Original Amount *</label>
                <input type="number" name="goodwill[original_amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.original_amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Carrying Value *</label>
                <input type="number" name="goodwill[carrying_value]" class="form-input" step="any" value={if @editing_item, do: @editing_item.carrying_value, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Reporting Unit</label>
                <input type="text" name="goodwill[reporting_unit]" class="form-input" value={if @editing_item, do: @editing_item.reporting_unit, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="goodwill[status]" class="form-select">
                  <%= for s <- ~w(active fully_impaired disposed) do %>
                    <option value={s} selected={(@editing_item && @editing_item.status == s) || (!@editing_item && s == "active")}>{humanize_type(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="goodwill[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Goodwill", else: "Add Goodwill"}</button>
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

    goodwill_list = Finance.list_goodwill(company_id)
    metrics = compute_metrics(goodwill_list)
    assign(socket, goodwill_list: goodwill_list, metrics: metrics)
  end

  defp compute_metrics(goodwill_list) do
    total_original =
      Enum.reduce(goodwill_list, Decimal.new(0), fn gw, acc ->
        Money.add(acc, Money.to_decimal(gw.original_amount))
      end)

    total_carrying =
      Enum.reduce(goodwill_list, Decimal.new(0), fn gw, acc ->
        Money.add(acc, Money.to_decimal(gw.carrying_value))
      end)

    total_impairment =
      Enum.reduce(goodwill_list, Decimal.new(0), fn gw, acc ->
        Money.add(acc, Money.to_decimal(gw.accumulated_impairment))
      end)

    active_count = Enum.count(goodwill_list, &(&1.status == "active"))

    %{
      total_original: total_original,
      total_carrying: total_carrying,
      total_impairment: total_impairment,
      active_count: active_count
    }
  end

  defp humanize_type(nil), do: "---"
  defp humanize_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("fully_impaired"), do: "tag-rose"
  defp status_tag("disposed"), do: "tag-lemon"
  defp status_tag(_), do: ""

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 2)) |> :erlang.float_to_binary(decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0.00"

  defp format_rate(nil), do: "---"
  defp format_rate(%Decimal{} = r), do: Money.format(r, 2)
  defp format_rate(r), do: Money.format(r, 2)

  defp add_commas(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int =
          int_part
          |> String.reverse()
          |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
          |> String.reverse()

        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
    end
  end
end
