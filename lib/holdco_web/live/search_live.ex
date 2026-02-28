defmodule HoldcoWeb.SearchLive do
  use HoldcoWeb, :live_view

  alias Holdco.Search

  @impl true
  def mount(%{"q" => query}, _session, socket) do
    results = Search.search(query)

    {:ok,
     assign(socket,
       page_title: "Search: #{query}",
       query: query,
       results: results
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Search",
       query: "",
       results: %{companies: [], holdings: [], transactions: [], documents: [], total: 0}
     )}
  end

  @impl true
  def handle_params(%{"q" => query}, _uri, socket) do
    results = Search.search(query)
    {:noreply, assign(socket, query: query, results: results, page_title: "Search: #{query}")}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/search?q=#{query}")}
  end

  @pages [
    {"Portfolio", [
      {"/holdings", "Positions"}, {"/transactions", "Transactions"}, {"/bank-accounts", "Bank Accounts"},
      {"/financials", "Financials"}, {"/scenarios", "Scenarios"}, {"/defi-positions", "DeFi Positions"},
    ]},
    {"Fund Management", [
      {"/capital-calls", "Capital Calls"}, {"/distributions", "Distributions"}, {"/fund-nav", "Fund NAV"},
      {"/investor-statements", "Investor Statements"}, {"/fund-fees", "Fees"}, {"/k1-reports", "K-1 Reports"},
      {"/dividend-policies", "Dividend Policies"}, {"/fundraising", "Fundraising"}, {"/partnership-basis", "Partnership Basis"}
    ]},
    {"Corporate", [
      {"/governance", "Governance"}, {"/compliance", "Compliance"}, {"/documents", "Documents"},
      {"/board-meetings", "Board Meetings"}, {"/shareholder-communications", "Shareholders"},
      {"/corporate-actions", "Corporate Actions"}, {"/entity-lifecycle", "Entity Lifecycle"},
      {"/registers", "Registers"}, {"/share-classes", "Share Classes"}, {"/lei", "LEI Tracking"},
      {"/signature-workflows", "Signatures"}, {"/contacts", "Contacts"}, {"/calendar", "Calendar"},
      {"/projects", "Projects"}, {"/compensation", "Compensation"}, {"/data-room", "Data Room"},
      {"/ethics", "Ethics"}
    ]},
    {"Legal & Compliance", [
      {"/contracts", "Contracts"}, {"/kyc", "KYC/AML"}, {"/aml-monitoring", "AML Monitoring"},
      {"/litigation", "Litigation"}, {"/insurance-claims", "Insurance Claims"},
      {"/bank-guarantees", "Bank Guarantees"}, {"/ip-assets", "IP Assets"},
      {"/conflicts-of-interest", "Conflicts of Interest"}, {"/related-party-transactions", "Related Party Txns"}
    ]},
    {"Accounting", [
      {"/accounts/chart", "Chart of Accounts"}, {"/accounts/journal", "Journal Entries"},
      {"/accounts/reports", "Reports"}, {"/accounts/integrations", "Integrations"},
      {"/depreciation", "Depreciation"}, {"/revaluation", "Revaluation"}, {"/segments", "Segments"},
      {"/consolidated", "Consolidated"}, {"/multi-book", "Multi-Book"}, {"/period-locks", "Period Locks"},
      {"/recurring-transactions", "Recurring"}, {"/bank-reconciliation", "Reconciliation"},
      {"/budgets/variance", "Budget Variance"}, {"/waterfall", "Waterfall"}, {"/leases", "Leases"},
      {"/service-agreements", "Service Agreements"}, {"/goodwill", "Goodwill"}
    ]},
    {"Tax", [
      {"/tax-provisions", "Tax Provisions"}, {"/deferred-taxes", "Deferred Taxes"},
      {"/tax-optimizer", "Tax Optimizer"}, {"/withholding-reclaims", "Withholding Reclaims"},
      {"/repatriation", "Repatriation"}, {"/transfer-pricing", "Transfer Pricing"},
      {"/tax/capital-gains", "Capital Gains"}, {"/tax-calendar", "Tax Calendar"}
    ]},
    {"Risk & Analytics", [
      {"/risk/concentration", "Concentration"}, {"/counterparty-risk", "Counterparty"},
      {"/covenants", "Covenants"}, {"/stress-test", "Stress Testing"}, {"/liquidity", "Liquidity"},
      {"/debt-maturity", "Debt Maturity"}, {"/cash-forecast", "Cash Forecast"},
      {"/esg", "ESG"}, {"/emissions", "Emissions"}, {"/regulatory-capital", "Regulatory Capital"},
      {"/regulatory-changes", "Regulatory Changes"}, {"/bcp", "Business Continuity"},
      {"/anomalies", "Anomalies"}, {"/benchmarks", "Benchmarks"}
    ]},
    {"Reports", [
      {"/reports", "Overview"}, {"/kpis", "KPIs"}, {"/aging", "Aging"},
      {"/management-reports", "Management Reports"}, {"/compare", "Entity Comparison"},
      {"/audit-diffs", "Audit Diffs"}, {"/scheduled-reports", "Scheduled Reports"},
      {"/reporting-templates", "Templates"}, {"/health-score", "Health Score"},
      {"/data-lineage", "Data Lineage"}
    ]},
    {"Family Office", [
      {"/trusts", "Trusts"}, {"/charitable-giving", "Charitable Giving"},
      {"/family-governance", "Family Governance"}, {"/estate-planning", "Estate Planning"}
    ]},
    {"Admin & Platform", [
      {"/settings", "Settings"}, {"/audit-log", "Audit Log"}, {"/custom-dashboards", "Custom Dashboards"},
      {"/sso-config", "SSO Config"}, {"/security-keys", "Security Keys"},
      {"/data-retention", "Data Retention"}, {"/plugins", "Plugins"}, {"/webhooks", "Webhooks"},
      {"/bi-connectors", "BI Connectors"}, {"/white-label", "White Label"},
      {"/approvals", "Approvals"}, {"/notifications", "Notifications"}, {"/import", "Import"},
      {"/bulk-edit", "Bulk Edit"}, {"/tasks", "Tasks"}, {"/alerts", "Alerts"},
      {"/activity", "Activity Feed"}, {"/collaboration", "Collaboration"},
      {"/document-intelligence", "Document Intelligence"}
    ]}
  ]

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :all_pages, @pages)

    ~H"""
    <div class="page-title">
      <h1>Search</h1>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <form phx-submit="search" style="margin-bottom: 1.5rem;">
        <div style="display: flex; gap: 0.5rem;">
          <input
            type="text"
            name="q"
            value={@query}
            placeholder="Search companies, positions, transactions, documents, or type a feature name..."
            class="form-input"
            style="flex: 1;"
            autofocus
          />
          <button type="submit" class="btn btn-primary">Search</button>
        </div>
      </form>
    </div>

    <%= if @query == "" do %>
      <div class="section">
        <div class="section-head">
          <h2>Browse All Features</h2>
          <span class="count"><%= Enum.reduce(@all_pages, 0, fn {_, pages}, acc -> acc + length(pages) end) %> pages</span>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1.5rem;">
          <%= for {category, pages} <- @all_pages do %>
            <div class="panel" style="padding: 1rem;">
              <h3 style="font-size: 0.8125rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-faint); margin-bottom: 0.5rem;"><%= category %></h3>
              <div style="display: flex; flex-direction: column; gap: 0.125rem;">
                <%= for {path, name} <- pages do %>
                  <.link navigate={path} style="font-size: 0.8125rem; color: var(--ink-light); text-decoration: none; padding: 0.2rem 0;" class="td-link"><%= name %></.link>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @query != "" do %>
      <div class="section">
        <div class="section-head">
          <h2>{@results.total} results for "{@query}"</h2>
        </div>
      </div>

      <%= if @results.companies != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>Companies</h2>
          </div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Detail</th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.companies do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/companies/#{r.id}"}>{r.name}</.link></td>
                    <td>{r.detail}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.holdings != [] do %>
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
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.holdings do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/holdings"}>{r.name}</.link></td>
                    <td class="td-mono">{r.detail}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.transactions != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>Transactions</h2>
          </div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Description</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.transactions do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/transactions"}>{r.name}</.link></td>
                    <td class="td-mono">{r.detail}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.documents != [] do %>
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
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.documents do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/documents"}>{r.name}</.link></td>
                    <td><span class="tag tag-ink">{r.detail}</span></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.total == 0 do %>
        <div class="section">
          <div class="panel">
            <div class="empty-state">No results found for "{@query}".</div>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end
end
