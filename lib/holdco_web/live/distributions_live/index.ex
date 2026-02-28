defmodule HoldcoWeb.DistributionsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Fund.subscribe()
    companies = Corporate.list_companies()
    distributions = Fund.list_distributions()

    {:ok,
     assign(socket,
       page_title: "Distributions",
       companies: companies,
       distributions: distributions,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       show_line_form: false,
       selected_distribution: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    distributions = Fund.list_distributions(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       distributions: distributions,
       selected_distribution: nil
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, show_line_form: false)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    dist = Fund.get_distribution!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: dist)}
  end

  def handle_event("select_distribution", %{"id" => id}, socket) do
    dist = Fund.get_distribution!(String.to_integer(id))
    {:noreply, assign(socket, selected_distribution: dist)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, selected_distribution: nil)}
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

  def handle_event("save", %{"distribution" => params}, socket) do
    case Fund.create_distribution(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Distribution created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create distribution")}
    end
  end

  def handle_event("update", %{"distribution" => params}, socket) do
    dist = socket.assigns.editing_item

    case Fund.update_distribution(dist, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Distribution updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update distribution")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    dist = Fund.get_distribution!(String.to_integer(id))

    case Fund.delete_distribution(dist) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_distribution && socket.assigns.selected_distribution.id == dist.id,
            do: nil,
            else: socket.assigns.selected_distribution

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Distribution deleted")
         |> assign(selected_distribution: selected)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete distribution")}
    end
  end

  def handle_event("save_line", %{"line" => params}, socket) do
    dist = socket.assigns.selected_distribution
    params = Map.put(params, "distribution_id", dist.id)

    case Fund.create_distribution_line(params) do
      {:ok, _} ->
        updated_dist = Fund.get_distribution!(dist.id)

        {:noreply,
         socket
         |> put_flash(:info, "Line added")
         |> assign(show_line_form: false, selected_distribution: updated_dist)
         |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add line")}
    end
  end

  def handle_event("approve", %{"id" => id}, socket) do
    dist = Fund.get_distribution!(String.to_integer(id))

    case Fund.update_distribution(dist, %{status: "approved"}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Distribution approved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve distribution")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket) when event in [:distributions_created, :distributions_updated, :distributions_deleted, :distribution_lines_created] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Distributions</h1>
          <p class="deck">Manage fund distributions to investors</p>
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
            <button class="btn btn-primary" phx-click="show_form">New Distribution</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Distributions</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Company</th>
              <th>Date</th>
              <th class="th-num">Total Amount</th>
              <th>Type</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for dist <- @distributions do %>
              <tr>
                <td class="td-mono">{dist.distribution_number || "-"}</td>
                <td>
                  <%= if dist.company do %>
                    <.link navigate={~p"/companies/#{dist.company.id}"} class="td-link">{dist.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{dist.distribution_date}</td>
                <td class="td-num">${format_number(dist.total_amount)}</td>
                <td><span class="tag">{dist.distribution_type || "-"}</span></td>
                <td><span class={"tag #{dist_status_tag(dist.status)}"}>{dist.status}</span></td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="select_distribution" phx-value-id={dist.id} class="btn btn-secondary btn-sm">View</button>
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={dist.id} class="btn btn-secondary btn-sm">Edit</button>
                      <%= if dist.status == "pending" do %>
                        <button phx-click="approve" phx-value-id={dist.id} class="btn btn-primary btn-sm">Approve</button>
                      <% end %>
                      <button phx-click="delete" phx-value-id={dist.id} class="btn btn-danger btn-sm" data-confirm="Delete this distribution?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @distributions == [] do %>
          <div class="empty-state">
            <p>No distributions found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Create First Distribution</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @selected_distribution do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Distribution Lines: #{@selected_distribution.distribution_number || "N/A"} - ${format_number(@selected_distribution.total_amount)}</h2>
          <div style="display: flex; gap: 0.5rem;">
            <%= if @can_write && @selected_distribution.status in ["pending", "approved"] do %>
              <button phx-click="show_line_form" class="btn btn-primary btn-sm">Add Line</button>
            <% end %>
            <button phx-click="close_detail" class="btn btn-secondary btn-sm">Close</button>
          </div>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Investor</th>
                <th class="th-num">Ownership %</th>
                <th class="th-num">Gross Amount</th>
                <th class="th-num">Withholding Tax</th>
                <th class="th-num">Net Amount</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for line <- @selected_distribution.lines do %>
                <tr>
                  <td class="td-name">{line.investor_name}</td>
                  <td class="td-num">{format_number(line.ownership_pct)}%</td>
                  <td class="td-num">${format_number(line.gross_amount)}</td>
                  <td class="td-num num-negative">${format_number(line.withholding_tax)}</td>
                  <td class="td-num num-positive">${format_number(line.net_amount)}</td>
                  <td><span class={"tag #{line_status_tag(line.status)}"}>{line.status}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @selected_distribution.lines == [] do %>
            <div class="empty-state">No distribution lines yet.</div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Distribution", else: "New Distribution"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="distribution[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Distribution Number</label>
                <input type="number" name="distribution[distribution_number]" class="form-input" value={if @editing_item, do: @editing_item.distribution_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Distribution Date *</label>
                <input type="date" name="distribution[distribution_date]" class="form-input" value={if @editing_item, do: @editing_item.distribution_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Total Amount *</label>
                <input type="number" name="distribution[total_amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.total_amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Distribution Type</label>
                <select name="distribution[distribution_type]" class="form-select">
                  <option value="">Select type</option>
                  <option value="return_of_capital" selected={@editing_item && @editing_item.distribution_type == "return_of_capital"}>Return of Capital</option>
                  <option value="profit" selected={@editing_item && @editing_item.distribution_type == "profit"}>Profit</option>
                  <option value="dividend" selected={@editing_item && @editing_item.distribution_type == "dividend"}>Dividend</option>
                  <option value="liquidation" selected={@editing_item && @editing_item.distribution_type == "liquidation"}>Liquidation</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="distribution[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
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
            <h3>Add Distribution Line</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_line">
              <div class="form-group">
                <label class="form-label">Investor Name *</label>
                <input type="text" name="line[investor_name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Ownership %</label>
                <input type="number" name="line[ownership_pct]" class="form-input" step="any" />
              </div>
              <div class="form-group">
                <label class="form-label">Gross Amount *</label>
                <input type="number" name="line[gross_amount]" class="form-input" step="any" required />
              </div>
              <div class="form-group">
                <label class="form-label">Withholding Tax</label>
                <input type="number" name="line[withholding_tax]" class="form-input" step="any" value="0" />
              </div>
              <div class="form-group">
                <label class="form-label">Net Amount</label>
                <input type="number" name="line[net_amount]" class="form-input" step="any" />
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

    distributions = Fund.list_distributions(company_id)
    assign(socket, distributions: distributions)
  end

  defp dist_status_tag("distributed"), do: "tag-jade"
  defp dist_status_tag("approved"), do: "tag-lemon"
  defp dist_status_tag("cancelled"), do: "tag-rose"
  defp dist_status_tag(_), do: "tag-sky"

  defp line_status_tag("distributed"), do: "tag-jade"
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
