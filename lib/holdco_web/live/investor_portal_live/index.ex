defmodule HoldcoWeb.InvestorPortalLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Assets, Governance, Documents, Money}

  @impl true
  def mount(_params, _session, socket) do
    accesses = socket.assigns.investor_accesses
    companies = socket.assigns.investor_companies

    first_access = List.first(accesses)
    selected_company = first_access && first_access.company

    active_tab = default_tab(first_access)

    socket =
      socket
      |> assign(
        page_title: "Investor Portal",
        companies: companies,
        accesses: accesses,
        selected_company: selected_company,
        selected_company_id: if(selected_company, do: selected_company.id),
        current_access: first_access,
        active_tab: active_tab,
        financials: [],
        holdings: [],
        cap_table: [],
        documents: []
      )
      |> load_tab_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("select_company", %{"company_id" => id}, socket) do
    company_id = String.to_integer(id)
    access = Enum.find(socket.assigns.accesses, &(&1.company_id == company_id))
    company = access && access.company
    active_tab = default_tab(access)

    socket =
      socket
      |> assign(
        selected_company: company,
        selected_company_id: company_id,
        current_access: access,
        active_tab: active_tab
      )
      |> load_tab_data()

    {:noreply, socket}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    access = socket.assigns.current_access

    allowed_tabs = allowed_tabs(access)

    if tab in allowed_tabs do
      {:noreply, socket |> assign(active_tab: tab) |> load_tab_data()}
    else
      {:noreply, socket}
    end
  end

  defp default_tab(nil), do: "financials"

  defp default_tab(access) do
    cond do
      access.can_view_financials -> "financials"
      access.can_view_holdings -> "holdings"
      access.can_view_cap_table -> "cap_table"
      access.can_view_documents -> "documents"
      true -> "financials"
    end
  end

  defp allowed_tabs(nil), do: []

  defp allowed_tabs(access) do
    tabs = []
    tabs = if access.can_view_financials, do: tabs ++ ["financials"], else: tabs
    tabs = if access.can_view_holdings, do: tabs ++ ["holdings"], else: tabs
    tabs = if access.can_view_cap_table, do: tabs ++ ["cap_table"], else: tabs
    tabs = if access.can_view_documents, do: tabs ++ ["documents"], else: tabs
    tabs
  end

  defp load_tab_data(socket) do
    company_id = socket.assigns.selected_company_id
    tab = socket.assigns.active_tab
    access = socket.assigns.current_access

    if is_nil(company_id) or is_nil(access) do
      assign(socket, financials: [], holdings: [], cap_table: [], documents: [])
    else
      case tab do
        "financials" when access.can_view_financials ->
          financials = Finance.list_financials(company_id)
          assign(socket, financials: financials)

        "holdings" when access.can_view_holdings ->
          holdings = Assets.list_holdings(%{company_id: company_id})
          assign(socket, holdings: holdings)

        "cap_table" when access.can_view_cap_table ->
          cap_table = Governance.list_cap_table_entries(company_id)
          assign(socket, cap_table: cap_table)

        "documents" when access.can_view_documents ->
          documents = Documents.list_documents(company_id)
          assign(socket, documents: documents)

        _ ->
          socket
      end
    end
  end

  defp tab_label("financials"), do: "Financials"
  defp tab_label("holdings"), do: "Positions"
  defp tab_label("cap_table"), do: "Cap Table"
  defp tab_label("documents"), do: "Documents"

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0.00"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int, dec] ->
        (int
         |> String.reverse()
         |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
         |> String.reverse()) <> "." <> dec

      [int] ->
        int |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Investor Portal</h1>
          <p class="deck">Read-only view of your portfolio companies</p>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="select_company" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <%= for c <- @companies do %>
            <option value={c.id} selected={c.id == @selected_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
    </div>

    <%= if @current_access do %>
      <div style="margin-bottom: 1rem; display: flex; gap: 0.25rem;">
        <%= for tab <- allowed_tabs(@current_access) do %>
          <button
            phx-click="select_tab"
            phx-value-tab={tab}
            class={"btn #{if @active_tab == tab, do: "btn-primary", else: "btn-secondary"} btn-sm"}
          >
            {tab_label(tab)}
          </button>
        <% end %>
      </div>

      <%= case @active_tab do %>
        <% "financials" -> %>
          {render_financials(assigns)}
        <% "holdings" -> %>
          {render_holdings(assigns)}
        <% "cap_table" -> %>
          {render_cap_table(assigns)}
        <% "documents" -> %>
          {render_documents(assigns)}
        <% _ -> %>
          <div class="empty-state">Select a tab above.</div>
      <% end %>
    <% else %>
      <div class="empty-state">No investor access found.</div>
    <% end %>
    """
  end

  defp render_financials(assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Financial Statements</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Period</th>
              <th class="th-num">Revenue</th>
              <th class="th-num">Expenses</th>
              <th class="th-num">Net Income</th>
              <th>Currency</th>
            </tr>
          </thead>
          <tbody>
            <%= for f <- @financials do %>
              <% net = Money.sub(f.revenue, f.expenses) %>
              <tr>
                <td class="td-mono">{f.period}</td>
                <td class="td-num num-positive">{format_number(f.revenue)}</td>
                <td class="td-num num-negative">{format_number(f.expenses)}</td>
                <td class={"td-num #{if Money.gte?(net, 0), do: "num-positive", else: "num-negative"}"}>
                  {format_number(net)}
                </td>
                <td>{f.currency}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @financials == [] do %>
          <div class="empty-state">No financial records available.</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_holdings(assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Positions</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Asset</th>
              <th>Ticker</th>
              <th class="th-num">Quantity</th>
              <th>Unit</th>
              <th>Type</th>
              <th>Currency</th>
            </tr>
          </thead>
          <tbody>
            <%= for h <- @holdings do %>
              <tr>
                <td class="td-name">{h.asset}</td>
                <td class="td-mono">{h.ticker || "---"}</td>
                <td class="td-num">{format_number(h.quantity)}</td>
                <td>{h.unit || "---"}</td>
                <td><span class="tag tag-ink">{h.asset_type}</span></td>
                <td>{h.currency}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @holdings == [] do %>
          <div class="empty-state">No holdings available.</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_cap_table(assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Cap Table</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Investor</th>
              <th>Round</th>
              <th>Instrument</th>
              <th class="th-num">Shares</th>
              <th class="th-num">Price/Share</th>
              <th class="th-num">Amount Invested</th>
              <th>Currency</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            <%= for ct <- @cap_table do %>
              <tr>
                <td class="td-name">{ct.investor}</td>
                <td>{ct.round_name}</td>
                <td>{ct.instrument_type}</td>
                <td class="td-num">{format_number(ct.shares)}</td>
                <td class="td-num">{if ct.price_per_share, do: format_number(ct.price_per_share), else: "---"}</td>
                <td class="td-num">{format_number(ct.amount_invested)}</td>
                <td>{ct.currency}</td>
                <td class="td-mono">{ct.date || "---"}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @cap_table == [] do %>
          <div class="empty-state">No cap table entries available.</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_documents(assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Documents</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Notes</th>
            </tr>
          </thead>
          <tbody>
            <%= for d <- @documents do %>
              <tr>
                <td class="td-name">{d.name}</td>
                <td>{d.doc_type || "---"}</td>
                <td>{d.notes || "---"}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @documents == [] do %>
          <div class="empty-state">No documents available.</div>
        <% end %>
      </div>
    </div>
    """
  end
end
