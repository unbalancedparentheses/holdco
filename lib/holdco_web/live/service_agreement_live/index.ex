defmodule HoldcoWeb.ServiceAgreementLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    agreements = Finance.list_service_agreements()

    {:ok,
     assign(socket,
       page_title: "Intragroup Service Agreements",
       companies: companies,
       agreements: agreements,
       selected_company_id: "",
       summary: nil,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    agreements = Finance.list_service_agreements(company_id)
    summary = if company_id, do: Finance.service_agreement_summary(company_id), else: nil

    {:noreply,
     assign(socket,
       selected_company_id: id,
       agreements: agreements,
       summary: summary
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    sa = Finance.get_service_agreement!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: sa)}
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

  def handle_event("save", %{"service_agreement" => params}, socket) do
    case Finance.create_service_agreement(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Service agreement created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create service agreement")}
    end
  end

  def handle_event("update", %{"service_agreement" => params}, socket) do
    sa = socket.assigns.editing_item

    case Finance.update_service_agreement(sa, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Service agreement updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update service agreement")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    sa = Finance.get_service_agreement!(String.to_integer(id))

    case Finance.delete_service_agreement(sa) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Service agreement deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete service agreement")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Intragroup Service Agreements</h1>
          <p class="deck">Manage intercompany service agreements, transfer pricing, and arm's length documentation</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Agreement</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @summary do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Agreements</div>
          <div class="metric-value">{@summary.total_agreements}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Inflows</div>
          <div class="metric-value">${format_number(@summary.total_inflows)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Outflows</div>
          <div class="metric-value num-negative">${format_number(@summary.total_outflows)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Net</div>
          <div class="metric-value">${format_number(@summary.net)}</div>
        </div>
      </div>

      <%= if @summary.by_type != [] do %>
        <div class="section">
          <div class="section-head"><h2>Breakdown by Type</h2></div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Agreement Type</th>
                  <th class="th-num">Count</th>
                  <th class="th-num">Total Amount</th>
                </tr>
              </thead>
              <tbody>
                <%= for row <- @summary.by_type do %>
                  <tr>
                    <td><span class="tag tag-jade">{humanize_type(row.type)}</span></td>
                    <td class="td-num">{row.count}</td>
                    <td class="td-num">${format_number(row.total)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>Agreements</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Provider</th>
              <th>Recipient</th>
              <th>Type</th>
              <th class="th-num">Amount</th>
              <th>Currency</th>
              <th>Frequency</th>
              <th>Status</th>
              <th>TP Method</th>
              <th class="td-mono">Start</th>
              <th class="td-mono">End</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for sa <- @agreements do %>
              <tr>
                <td class="td-name">{if sa.provider_company, do: sa.provider_company.name, else: "---"}</td>
                <td class="td-name">{if sa.recipient_company, do: sa.recipient_company.name, else: "---"}</td>
                <td><span class="tag tag-jade">{humanize_type(sa.agreement_type)}</span></td>
                <td class="td-num">{format_number(sa.amount)}</td>
                <td>{sa.currency || "USD"}</td>
                <td>{humanize_type(sa.frequency)}</td>
                <td><span class={"tag #{status_tag(sa.status)}"}>{humanize_type(sa.status)}</span></td>
                <td>{humanize_type(sa.transfer_pricing_method)}</td>
                <td class="td-mono">{sa.start_date || "---"}</td>
                <td class="td-mono">{sa.end_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={sa.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={sa.id} class="btn btn-danger btn-sm" data-confirm="Delete this agreement?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @agreements == [] do %>
          <div class="empty-state">
            <p>No service agreements found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Agreement</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Service Agreement", else: "Add Service Agreement"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Provider Company *</label>
                <select name="service_agreement[provider_company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.provider_company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Recipient Company *</label>
                <select name="service_agreement[recipient_company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.recipient_company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Agreement Type *</label>
                <select name="service_agreement[agreement_type]" class="form-select" required>
                  <%= for t <- ~w(management_fee shared_services licensing royalty cost_sharing other) do %>
                    <option value={t} selected={@editing_item && @editing_item.agreement_type == t}>{humanize_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="service_agreement[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="service_agreement[amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <select name="service_agreement[currency]" class="form-select">
                  <%= for cur <- ~w(USD EUR GBP CHF JPY AUD CAD) do %>
                    <option value={cur} selected={(@editing_item && @editing_item.currency == cur) || (!@editing_item && cur == "USD")}>{cur}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Frequency</label>
                <select name="service_agreement[frequency]" class="form-select">
                  <%= for f <- ~w(monthly quarterly annually) do %>
                    <option value={f} selected={(@editing_item && @editing_item.frequency == f) || (!@editing_item && f == "monthly")}>{humanize_type(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Start Date</label>
                <input type="date" name="service_agreement[start_date]" class="form-input" value={if @editing_item, do: @editing_item.start_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">End Date</label>
                <input type="date" name="service_agreement[end_date]" class="form-input" value={if @editing_item, do: @editing_item.end_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Markup %</label>
                <input type="number" name="service_agreement[markup_pct]" class="form-input" step="any" value={if @editing_item, do: @editing_item.markup_pct, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Arm's Length Basis</label>
                <textarea name="service_agreement[arm_length_basis]" class="form-input">{if @editing_item, do: @editing_item.arm_length_basis, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Transfer Pricing Method</label>
                <select name="service_agreement[transfer_pricing_method]" class="form-select">
                  <option value="">-- None --</option>
                  <%= for m <- ~w(comparable_uncontrolled resale_price cost_plus profit_split tnmm) do %>
                    <option value={m} selected={@editing_item && @editing_item.transfer_pricing_method == m}>{humanize_type(m)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="service_agreement[status]" class="form-select">
                  <%= for s <- ~w(draft active expired terminated) do %>
                    <option value={s} selected={(@editing_item && @editing_item.status == s) || (!@editing_item && s == "draft")}>{humanize_type(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="service_agreement[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Agreement", else: "Add Agreement"}</button>
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

    agreements = Finance.list_service_agreements(company_id)
    summary = if company_id, do: Finance.service_agreement_summary(company_id), else: nil
    assign(socket, agreements: agreements, summary: summary)
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
  defp status_tag("draft"), do: "tag-lemon"
  defp status_tag("expired"), do: "tag-rose"
  defp status_tag("terminated"), do: "tag-rose"
  defp status_tag(_), do: ""

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 2)) |> :erlang.float_to_binary(decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0.00"

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
