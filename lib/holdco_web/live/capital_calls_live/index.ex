defmodule HoldcoWeb.CapitalCallsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Fund.subscribe()
    companies = Corporate.list_companies()
    calls = Fund.list_capital_calls()

    {:ok,
     assign(socket,
       page_title: "Capital Calls",
       companies: companies,
       calls: calls,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       show_line_form: false,
       selected_call: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    calls = Fund.list_capital_calls(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       calls: calls,
       selected_call: nil
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, show_line_form: false)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    call = Fund.get_capital_call!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: call)}
  end

  def handle_event("select_call", %{"id" => id}, socket) do
    call = Fund.get_capital_call!(String.to_integer(id))
    {:noreply, assign(socket, selected_call: call)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, selected_call: nil)}
  end

  def handle_event("show_line_form", _, socket) do
    {:noreply, assign(socket, show_line_form: true)}
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

  def handle_event("save", %{"capital_call" => params}, socket) do
    case Fund.create_capital_call(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Capital call created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create capital call")}
    end
  end

  def handle_event("update", %{"capital_call" => params}, socket) do
    call = socket.assigns.editing_item

    case Fund.update_capital_call(call, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Capital call updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update capital call")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    call = Fund.get_capital_call!(String.to_integer(id))

    case Fund.delete_capital_call(call) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_call && socket.assigns.selected_call.id == call.id,
            do: nil,
            else: socket.assigns.selected_call

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Capital call deleted")
         |> assign(selected_call: selected)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete capital call")}
    end
  end

  def handle_event("save_line", %{"line" => params}, socket) do
    call = socket.assigns.selected_call
    params = Map.put(params, "capital_call_id", call.id)

    case Fund.create_capital_call_line(params) do
      {:ok, _} ->
        updated_call = Fund.get_capital_call!(call.id)

        {:noreply,
         socket
         |> put_flash(:info, "Line added")
         |> assign(show_line_form: false, selected_call: updated_call)
         |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add line")}
    end
  end

  def handle_event("mark_paid", %{"id" => id}, socket) do
    line = Fund.get_capital_call_line!(String.to_integer(id))

    case Fund.mark_line_paid(line, line.call_amount) do
      {:ok, _} ->
        call = Fund.get_capital_call!(socket.assigns.selected_call.id)

        {:noreply,
         socket
         |> put_flash(:info, "Line marked as paid")
         |> assign(selected_call: call)
         |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to mark line as paid")}
    end
  end

  def handle_event("cancel_call", %{"id" => id}, socket) do
    call = Fund.get_capital_call!(String.to_integer(id))

    case Fund.update_capital_call(call, %{status: "cancelled"}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Capital call cancelled")
         |> assign(selected_call: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel capital call")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket) when event in [:capital_calls_created, :capital_calls_updated, :capital_calls_deleted, :capital_call_lines_created, :capital_call_lines_updated] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Capital Calls</h1>
          <p class="deck">Manage fund capital calls and investor commitments</p>
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
            <button class="btn btn-primary" phx-click="show_form">New Capital Call</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Capital Calls</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Company</th>
              <th>Call Date</th>
              <th>Due Date</th>
              <th class="th-num">Total Amount</th>
              <th>Purpose</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for call <- @calls do %>
              <tr>
                <td class="td-mono">{call.call_number || "-"}</td>
                <td>
                  <%= if call.company do %>
                    <.link navigate={~p"/companies/#{call.company.id}"} class="td-link">{call.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{call.call_date}</td>
                <td class="td-mono">{call.due_date || "-"}</td>
                <td class="td-num">${format_number(call.total_amount)}</td>
                <td><span class="tag">{call.purpose || "-"}</span></td>
                <td><span class={"tag #{status_tag(call.status)}"}>{call.status}</span></td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="select_call" phx-value-id={call.id} class="btn btn-secondary btn-sm">View</button>
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={call.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={call.id} class="btn btn-danger btn-sm" data-confirm="Delete this capital call?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @calls == [] do %>
          <div class="empty-state">
            <p>No capital calls found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Create First Capital Call</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @selected_call do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Call Lines: {@selected_call.call_number || "N/A"} - ${format_number(@selected_call.total_amount)}</h2>
          <div style="display: flex; gap: 0.5rem;">
            <%= if @can_write && @selected_call.status not in ["funded", "cancelled"] do %>
              <button phx-click="show_line_form" class="btn btn-primary btn-sm">Add Line</button>
              <button phx-click="cancel_call" phx-value-id={@selected_call.id} class="btn btn-danger btn-sm" data-confirm="Cancel this call?">Cancel Call</button>
            <% end %>
            <button phx-click="close_detail" class="btn btn-secondary btn-sm">Close</button>
          </div>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Investor</th>
                <th class="th-num">Commitment</th>
                <th class="th-num">Call Amount</th>
                <th class="th-num">Paid Amount</th>
                <th>Status</th>
                <th>Paid Date</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for line <- @selected_call.lines do %>
                <tr>
                  <td class="td-name">{line.investor_name}</td>
                  <td class="td-num">{format_number(line.commitment_amount)}</td>
                  <td class="td-num">{format_number(line.call_amount)}</td>
                  <td class="td-num">{format_number(line.paid_amount)}</td>
                  <td><span class={"tag #{line_status_tag(line.status)}"}>{line.status}</span></td>
                  <td class="td-mono">{line.paid_date || "-"}</td>
                  <td>
                    <%= if @can_write && line.status == "pending" do %>
                      <button phx-click="mark_paid" phx-value-id={line.id} class="btn btn-primary btn-sm">Mark Paid</button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @selected_call.lines == [] do %>
            <div class="empty-state">No lines yet for this capital call.</div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Capital Call", else: "New Capital Call"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="capital_call[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Call Number</label>
                <input type="number" name="capital_call[call_number]" class="form-input" value={if @editing_item, do: @editing_item.call_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Call Date *</label>
                <input type="date" name="capital_call[call_date]" class="form-input" value={if @editing_item, do: @editing_item.call_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Due Date</label>
                <input type="date" name="capital_call[due_date]" class="form-input" value={if @editing_item, do: @editing_item.due_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Total Amount *</label>
                <input type="number" name="capital_call[total_amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.total_amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Purpose</label>
                <select name="capital_call[purpose]" class="form-select">
                  <option value="">Select purpose</option>
                  <option value="investment" selected={@editing_item && @editing_item.purpose == "investment"}>Investment</option>
                  <option value="fees" selected={@editing_item && @editing_item.purpose == "fees"}>Fees</option>
                  <option value="expenses" selected={@editing_item && @editing_item.purpose == "expenses"}>Expenses</option>
                  <option value="follow_on" selected={@editing_item && @editing_item.purpose == "follow_on"}>Follow-on</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="capital_call[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
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

    <%= if @show_line_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add Call Line</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_line">
              <div class="form-group">
                <label class="form-label">Investor Name *</label>
                <input type="text" name="line[investor_name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Commitment Amount</label>
                <input type="number" name="line[commitment_amount]" class="form-input" step="any" />
              </div>
              <div class="form-group">
                <label class="form-label">Call Amount *</label>
                <input type="number" name="line[call_amount]" class="form-input" step="any" required />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Line</button>
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

    calls = Fund.list_capital_calls(company_id)
    assign(socket, calls: calls)
  end

  defp status_tag("funded"), do: "tag-jade"
  defp status_tag("partially_funded"), do: "tag-lemon"
  defp status_tag("cancelled"), do: "tag-rose"
  defp status_tag(_), do: "tag-sky"

  defp line_status_tag("paid"), do: "tag-jade"
  defp line_status_tag("overdue"), do: "tag-rose"
  defp line_status_tag(_), do: "tag-sky"

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
