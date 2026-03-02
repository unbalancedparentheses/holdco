defmodule HoldcoWeb.CompanyLive.ShowTabs do
  @moduledoc false
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: HoldcoWeb.Endpoint,
    router: HoldcoWeb.Router,
    statics: HoldcoWeb.static_paths()

  import HoldcoWeb.CompanyLive.ShowHelpers
  import HoldcoWeb.CompanyLive.ShowForms, only: [render_inline_form: 1]

  alias Holdco.Money

  attr :is_consolidated, :boolean, required: true
  attr :name, :string, default: nil

  def company_col(assigns) do
    ~H"""
    <%= if @is_consolidated do %>
      <%= if @name do %>
        <td>{@name}</td>
      <% else %>
        <th>Company</th>
      <% end %>
    <% end %>
    """
  end

  def render_tab(%{active_tab: "overview"} = assigns) do
    ~H"""
    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Company Details</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <dl class="detail-list">
            <div>
              <dt>Legal Name</dt>
              <dd>{@company.legal_name || @company.name}</dd>
            </div>
            <div>
              <dt>Country</dt>
              <dd>{@company.country}</dd>
            </div>
            <div>
              <dt>Category</dt>
              <dd>{@company.category}</dd>
            </div>
            <div>
              <dt>Tax ID</dt>
              <dd>{@company.tax_id || "---"}</dd>
            </div>
            <div>
              <dt>KYC Status</dt>
              <dd>
                <span class={"tag #{kyc_tag(@company.kyc_status)}"}>{@company.kyc_status}</span>
              </dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>
                <span class={"tag #{status_tag(@company.wind_down_status)}"}>
                  {@company.wind_down_status}
                </span>
              </dd>
            </div>
            <div>
              <dt>Formation Date</dt>
              <dd>{@company.formation_date || "---"}</dd>
            </div>
            <div>
              <dt>Website</dt>
              <dd>{@company.website || "---"}</dd>
            </div>
            <div>
              <dt>Lawyer/Studio</dt>
              <dd>{@company.lawyer_studio || "---"}</dd>
            </div>
          </dl>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Key Personnel</h2>
          <%= if @can_write do %>
            <button
              class="btn btn-sm btn-primary"
              phx-click="show_form"
              phx-value-form="key_personnel"
            >
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Title</th>
                <th>Email</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for kp <- @company.key_personnel do %>
                <tr>
                  <td class="td-name">{kp.name}</td>
                  <td>{kp.title}</td>
                  <td>{kp.email}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_key_personnel"
                        phx-value-id={kp.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="section-head" style="margin-top: 1rem;">
          <h2>Beneficial Owners</h2>
          <%= if @can_write do %>
            <button
              class="btn btn-sm btn-primary"
              phx-click="show_form"
              phx-value-form="beneficial_owner"
            >
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Nationality</th>
                <th>Ownership %</th>
                <th>Verified</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for bo <- @company.beneficial_owners do %>
                <tr>
                  <td class="td-name">{bo.name}</td>
                  <td>{bo.nationality}</td>
                  <td class="td-num">{bo.ownership_pct}%</td>
                  <td>{if bo.verified, do: "Yes", else: "No"}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_beneficial_owner"
                        phx-value-id={bo.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="section-head" style="margin-top: 1rem;">
          <h2>Service Providers</h2>
          <%= if @can_write do %>
            <button
              class="btn btn-sm btn-primary"
              phx-click="show_form"
              phx-value-form="service_provider"
            >
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Role</th>
                <th>Name</th>
                <th>Firm</th>
                <th>Email</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for sp <- @company.service_providers do %>
                <tr>
                  <td>{sp.role}</td>
                  <td class="td-name">{sp.name}</td>
                  <td>{sp.firm}</td>
                  <td>{sp.email}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_service_provider"
                        phx-value-id={sp.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <%= if @company.subsidiaries != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Subsidiaries</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Country</th>
                <th>Ownership</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for sub <- @company.subsidiaries do %>
                <tr>
                  <td>
                    <.link navigate={~p"/companies/#{sub.id}"} class="td-link td-name">
                      {sub.name}
                    </.link>
                  </td>
                  <td>{sub.country}</td>
                  <td class="td-num">
                    {if sub.ownership_pct, do: "#{sub.ownership_pct}%", else: "---"}
                  </td>
                  <td>
                    <span class={"tag #{status_tag(sub.wind_down_status)}"}>
                      {sub.wind_down_status}
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "holdings"} = assigns) do
    assigns = assign(assigns, holdings_rows: rows(assigns, :asset_holdings))

    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Positions</h2>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <.link navigate={~p"/holdings"} class="count" style="text-decoration: none;">View all &rarr;</.link>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="holding">
              Add Position
            </button>
          <% end %>
        </div>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Asset</th>
              <th>Ticker</th>
              <th>Qty</th>
              <th>Unit</th>
              <th>Type</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {h, company_name} <- @holdings_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-name">{h.asset}</td>
                <td class="td-mono">{h.ticker}</td>
                <td class="td-num">{h.quantity}</td>
                <td>{h.unit}</td>
                <td><span class="tag tag-ink">{h.asset_type}</span></td>
                <td>{h.currency}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_holding"
                      phx-value-id={h.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @holdings_rows == [] do %>
          <div class="empty-state">No holdings for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "bank_accounts"} = assigns) do
    assigns = assign(assigns, ba_rows: rows(assigns, :bank_accounts))

    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Bank Accounts</h2>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <.link navigate={~p"/bank-accounts"} class="count" style="text-decoration: none;">View all &rarr;</.link>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="bank_account">
              Add Account
            </button>
          <% end %>
        </div>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Bank</th>
              <th>Account #</th>
              <th>IBAN</th>
              <th>Type</th>
              <th>Currency</th>
              <th class="th-num">Balance</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {ba, company_name} <- @ba_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-name">{ba.bank_name}</td>
                <td class="td-mono">{ba.account_number}</td>
                <td class="td-mono">{ba.iban}</td>
                <td>{ba.account_type}</td>
                <td>{ba.currency}</td>
                <td class="td-num">{ba.balance}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_bank_account"
                      phx-value-id={ba.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @ba_rows == [] do %>
          <div class="empty-state">No bank accounts for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "transactions"} = assigns) do
    assigns = assign(assigns, tx_rows: rows(assigns, :transactions))

    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Transactions</h2>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <.link navigate={~p"/transactions"} class="count" style="text-decoration: none;">View all &rarr;</.link>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="transaction">
              Add Transaction
            </button>
          <% end %>
        </div>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Date</th>
              <th>Type</th>
              <th>Description</th>
              <th>Counterparty</th>
              <th class="th-num">Amount</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {tx, company_name} <- @tx_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-mono">{tx.date}</td>
                <td><span class="tag tag-ink">{tx.transaction_type}</span></td>
                <td class="td-name">{tx.description}</td>
                <td>{tx.counterparty}</td>
                <td class={"td-num #{if tx.amount && tx.amount < 0, do: "num-negative", else: "num-positive"}"}>
                  {tx.amount}
                </td>
                <td>{tx.currency}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_transaction"
                      phx-value-id={tx.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @tx_rows == [] do %>
          <div class="empty-state">No transactions for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "documents"} = assigns) do
    assigns = assign(assigns, doc_rows: rows(assigns, :documents))

    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Documents</h2>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <.link navigate={~p"/documents"} class="count" style="text-decoration: none;">View all &rarr;</.link>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="document">
              Add Document
            </button>
          <% end %>
        </div>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Name</th>
              <th>Type</th>
              <th>URL</th>
              <th>Notes</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {doc, company_name} <- @doc_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-name">{doc.name}</td>
                <td><span class="tag tag-ink">{doc.doc_type}</span></td>
                <td>{if doc.url, do: doc.url, else: "---"}</td>
                <td>{doc.notes}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_document"
                      phx-value-id={doc.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @doc_rows == [] do %>
          <div class="empty-state">No documents for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "governance"} = assigns) do
    assigns =
      assign(assigns,
        bm_rows: rows(assigns, :board_meetings),
        ct_rows: rows(assigns, :cap_table),
        res_rows: rows(assigns, :resolutions),
        deal_rows: rows(assigns, :deals),
        jv_rows: rows(assigns, :joint_ventures),
        poa_rows: rows(assigns, :powers_of_attorney),
        ep_rows: rows(assigns, :equity_plans)
      )

    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Board Meetings</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="board_meeting">
            Add Meeting
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Date</th>
              <th>Type</th>
              <th>Status</th>
              <th>Notes</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {bm, company_name} <- @bm_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-mono">{bm.scheduled_date}</td>
                <td>{bm.meeting_type}</td>
                <td><span class={"tag #{meeting_status_tag(bm.status)}"}>{bm.status}</span></td>
                <td>{bm.notes}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_board_meeting"
                      phx-value-id={bm.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Cap Table</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="cap_table">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Investor</th>
                <th>Round</th>
                <th>Shares</th>
                <th>Amount</th>
                <th>Date</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {ct, company_name} <- @ct_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td class="td-name">{ct.investor}</td>
                  <td>{ct.round_name}</td>
                  <td class="td-num">{ct.shares}</td>
                  <td class="td-num">{ct.amount_invested} {ct.currency}</td>
                  <td class="td-mono">{ct.date}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_cap_table"
                        phx-value-id={ct.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Resolutions</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="resolution">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Title</th>
                <th>Type</th>
                <th>Date</th>
                <th>Passed</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {res, company_name} <- @res_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td class="td-name">{res.title}</td>
                  <td>{res.resolution_type}</td>
                  <td class="td-mono">{res.date}</td>
                  <td>{if res.passed, do: "Yes", else: "No"}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_resolution"
                        phx-value-id={res.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Deals</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="deal">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Type</th>
                <th>Counterparty</th>
                <th>Value</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {deal, company_name} <- @deal_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td>{deal.deal_type}</td>
                  <td class="td-name">{deal.counterparty}</td>
                  <td class="td-num">{deal.value} {deal.currency}</td>
                  <td><span class="tag tag-ink">{deal.status}</span></td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_deal"
                        phx-value-id={deal.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Joint Ventures</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="jv">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Name</th>
                <th>Partner</th>
                <th>Ownership</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {jv, company_name} <- @jv_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td class="td-name">{jv.name}</td>
                  <td>{jv.partner}</td>
                  <td class="td-num">{jv.ownership_pct}%</td>
                  <td><span class={"tag #{status_tag(jv.status)}"}>{jv.status}</span></td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_jv"
                        phx-value-id={jv.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
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
        <h2>Powers of Attorney</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="poa">
            Add
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Grantor</th>
              <th>Grantee</th>
              <th>Scope</th>
              <th>Start</th>
              <th>End</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {poa, company_name} <- @poa_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-name">{poa.grantor}</td>
                <td>{poa.grantee}</td>
                <td>{poa.scope}</td>
                <td class="td-mono">{poa.start_date}</td>
                <td class="td-mono">{poa.end_date}</td>
                <td><span class={"tag #{status_tag(poa.status)}"}>{poa.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_poa"
                      phx-value-id={poa.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Equity Plans</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="equity_plan">
            Add
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Plan Name</th>
              <th>Total Pool</th>
              <th>Vesting Schedule</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {ep, company_name} <- @ep_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-name">{ep.plan_name}</td>
                <td class="td-num">{ep.total_pool}</td>
                <td>{ep.vesting_schedule}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_equity_plan"
                      phx-value-id={ep.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "compliance"} = assigns) do
    assigns =
      assign(assigns,
        td_rows: rows(assigns, :tax_deadlines),
        ip_rows: rows(assigns, :insurance_policies),
        rf_rows: rows(assigns, :regulatory_filings),
        rl_rows: rows(assigns, :regulatory_licenses),
        esg_rows: rows(assigns, :esg_scores),
        sc_rows: rows(assigns, :sanctions_checks),
        fatca_rows: rows(assigns, :fatca_reports),
        wt_rows: rows(assigns, :withholding_taxes)
      )

    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Tax Deadlines</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="tax_deadline">
            Add Deadline
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Jurisdiction</th>
              <th>Description</th>
              <th>Due Date</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {td, company_name} <- @td_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td>{td.jurisdiction}</td>
                <td class="td-name">{td.description}</td>
                <td class="td-mono">{td.due_date}</td>
                <td><span class={"tag #{deadline_status_tag(td.status)}"}>{td.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_tax_deadline"
                      phx-value-id={td.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Insurance Policies</h2>
          <%= if @can_write do %>
            <button
              class="btn btn-sm btn-primary"
              phx-click="show_form"
              phx-value-form="insurance_policy"
            >
              Add Policy
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Type</th>
                <th>Provider</th>
                <th>Coverage</th>
                <th>Expiry</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {ip, company_name} <- @ip_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td>{ip.policy_type}</td>
                  <td class="td-name">{ip.provider}</td>
                  <td class="td-num">{ip.coverage_amount} {ip.currency}</td>
                  <td class="td-mono">{ip.expiry_date}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_insurance_policy"
                        phx-value-id={ip.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Regulatory Filings</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="filing">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Jurisdiction</th>
                <th>Type</th>
                <th>Due</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {rf, company_name} <- @rf_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td>{rf.jurisdiction}</td>
                  <td>{rf.filing_type}</td>
                  <td class="td-mono">{rf.due_date}</td>
                  <td><span class={"tag #{deadline_status_tag(rf.status)}"}>{rf.status}</span></td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_filing"
                        phx-value-id={rf.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Regulatory Licenses</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="license">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Type</th>
                <th>Authority</th>
                <th>Expiry</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {rl, company_name} <- @rl_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td>{rl.license_type}</td>
                  <td>{rl.issuing_authority}</td>
                  <td class="td-mono">{rl.expiry_date}</td>
                  <td><span class={"tag #{status_tag(rl.status)}"}>{rl.status}</span></td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_license"
                        phx-value-id={rl.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>ESG Scores</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="esg">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Period</th>
                <th>E</th>
                <th>S</th>
                <th>G</th>
                <th>Overall</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {esg, company_name} <- @esg_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td>{esg.period}</td>
                  <td class="td-num">{esg.environmental_score}</td>
                  <td class="td-num">{esg.social_score}</td>
                  <td class="td-num">{esg.governance_score}</td>
                  <td class="td-num">{esg.overall_score}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_esg"
                        phx-value-id={esg.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
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
        <h2>Sanctions Checks</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="sanctions">
            Add
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Name Checked</th>
              <th>Status</th>
              <th>Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {sc, company_name} <- @sc_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-name">{sc.checked_name}</td>
                <td><span class={"tag #{sanctions_status_tag(sc.status)}"}>{sc.status}</span></td>
                <td class="td-mono">{Calendar.strftime(sc.inserted_at, "%Y-%m-%d")}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_sanctions"
                      phx-value-id={sc.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>FATCA Reports</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="fatca">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Year</th>
                <th>Jurisdiction</th>
                <th>Type</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {fr, company_name} <- @fatca_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td class="td-mono">{fr.reporting_year}</td>
                  <td>{fr.jurisdiction}</td>
                  <td>{fr.report_type}</td>
                  <td><span class={"tag #{deadline_status_tag(fr.status)}"}>{fr.status}</span></td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_fatca"
                        phx-value-id={fr.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Withholding Taxes</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="withholding">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Date</th>
                <th>Payment Type</th>
                <th>From</th>
                <th>To</th>
                <th class="th-num">Gross</th>
                <th>Rate %</th>
                <th class="th-num">Tax</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {wt, company_name} <- @wt_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td class="td-mono">{wt.date}</td>
                  <td>{wt.payment_type}</td>
                  <td>{wt.country_from}</td>
                  <td>{wt.country_to}</td>
                  <td class="td-num">{wt.gross_amount}</td>
                  <td class="td-num">{wt.rate}%</td>
                  <td class="td-num">{wt.tax_amount}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_withholding"
                        phx-value-id={wt.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "financials"} = assigns) do
    assigns =
      assign(assigns,
        fin_rows: rows(assigns, :financials),
        liab_rows: rows(assigns, :liabilities),
        div_rows: rows(assigns, :dividends)
      )

    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Financials</h2>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <.link navigate={~p"/financials"} class="count" style="text-decoration: none;">View all &rarr;</.link>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="financial">
              Add Period
            </button>
          <% end %>
        </div>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Period</th>
              <th class="th-num">Revenue</th>
              <th class="th-num">Expenses</th>
              <th class="th-num">Net</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {f, company_name} <- @fin_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-mono">{f.period}</td>
                <td class="td-num num-positive">{f.revenue}</td>
                <td class="td-num num-negative">{f.expenses}</td>
                <td class={"td-num #{if Money.gte?(Money.sub(f.revenue, f.expenses), 0), do: "num-positive", else: "num-negative"}"}>
                  {Money.sub(f.revenue, f.expenses)}
                </td>
                <td>{f.currency}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_financial"
                      phx-value-id={f.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @fin_rows == [] do %>
          <div class="empty-state">No financial records yet.</div>
        <% end %>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Liabilities</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="liability">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Type</th>
                <th>Creditor</th>
                <th class="th-num">Principal</th>
                <th>Rate</th>
                <th>Maturity</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {l, company_name} <- @liab_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td>{l.liability_type}</td>
                  <td class="td-name">{l.creditor}</td>
                  <td class="td-num">{l.principal} {l.currency}</td>
                  <td class="td-num">{l.interest_rate}%</td>
                  <td class="td-mono">{l.maturity_date}</td>
                  <td><span class={"tag #{status_tag(l.status)}"}>{l.status}</span></td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_liability"
                        phx-value-id={l.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Dividends</h2>
          <%= if @can_write do %>
            <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="dividend">
              Add
            </button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <.company_col is_consolidated={@is_consolidated} />
                <th>Date</th>
                <th>Recipient</th>
                <th class="th-num">Amount</th>
                <th>Type</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {d, company_name} <- @div_rows do %>
                <tr>
                  <.company_col is_consolidated={@is_consolidated} name={company_name} />
                  <td class="td-mono">{d.date}</td>
                  <td class="td-name">{d.recipient}</td>
                  <td class="td-num">{d.amount} {d.currency}</td>
                  <td>{d.dividend_type}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete_dividend"
                        phx-value-id={d.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "accounting"} = assigns) do
    acct_rows = rows(assigns, :accounts)
    je_rows = rows(assigns, :journal_entries)
    acct_list = Enum.map(acct_rows, &elem(&1, 0))
    je_list = Enum.map(je_rows, &elem(&1, 0))

    assigns = assign(assigns, acct_rows: acct_rows, je_rows: je_rows, acct_list: acct_list, je_list: je_list)

    ~H"""
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Accounts</div>
        <div class="metric-value">{length(@acct_list)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Journal Entries</div>
        <div class="metric-value">{length(@je_list)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Debits</div>
        <div class="metric-value">
          {format_number(Enum.reduce(@je_list, Decimal.new(0), fn e, acc ->
            Money.add(acc, Enum.reduce(e.lines || [], Decimal.new(0), fn l, a -> Money.add(a, l.debit) end))
          end))}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Credits</div>
        <div class="metric-value">
          {format_number(Enum.reduce(@je_list, Decimal.new(0), fn e, acc ->
            Money.add(acc, Enum.reduce(e.lines || [], Decimal.new(0), fn l, a -> Money.add(a, l.credit) end))
          end))}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Chart of Accounts</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="account">
            Add Account
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Code</th>
              <th>Name</th>
              <th>Type</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {a, company_name} <- @acct_rows do %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-mono">{a.code}</td>
                <td>{a.name}</td>
                <td><span class={"badge badge-#{a.account_type}"}>{a.account_type}</span></td>
                <td>{a.currency}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_account"
                      phx-value-id={a.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete this account?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @acct_rows == [] do %>
          <div class="empty-state">No accounts for this company.</div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Journal Entries</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="journal_entry">
            New Entry
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <.company_col is_consolidated={@is_consolidated} />
              <th>Date</th>
              <th>Reference</th>
              <th>Description</th>
              <th class="th-num">Debit</th>
              <th class="th-num">Credit</th>
              <th class="th-num">Lines</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {entry, company_name} <- @je_rows do %>
              <% {total_debit, total_credit} = entry_totals(entry) %>
              <tr>
                <.company_col is_consolidated={@is_consolidated} name={company_name} />
                <td class="td-mono">{entry.date}</td>
                <td>{entry.reference || "—"}</td>
                <td>{entry.description}</td>
                <td class="td-num">{format_number(total_debit)}</td>
                <td class="td-num">{format_number(total_credit)}</td>
                <td class="td-num">{length(entry.lines || [])}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_journal_entry"
                      phx-value-id={entry.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete this journal entry and all its lines?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @je_rows == [] do %>
          <div class="empty-state">No journal entries for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  def render_tab(%{active_tab: "integrations"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>QuickBooks Online</h2>
      </div>
      <div class="panel" style="padding: 1.5rem;">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.5rem;">
              <strong style="font-size: 1.1rem;">QuickBooks Online</strong>
              <%= if @qbo_integration && @qbo_integration.status == "connected" do %>
                <span class="badge badge-asset">Connected</span>
              <% else %>
                <span class="badge badge-expense">Disconnected</span>
              <% end %>
            </div>
            <p style="color: var(--color-muted); margin: 0;">
              Sync chart of accounts and journal entries from QuickBooks Online.
            </p>
            <%= if @qbo_integration && @qbo_integration.realm_id do %>
              <p style="color: var(--color-muted); margin: 0.25rem 0 0; font-size: 0.85rem;">
                QBO Company ID: {@qbo_integration.realm_id}
              </p>
            <% end %>
            <%= if @qbo_integration && @qbo_integration.last_synced_at do %>
              <p style="color: var(--color-muted); margin: 0.25rem 0 0; font-size: 0.85rem;">
                Last synced: {Calendar.strftime(@qbo_integration.last_synced_at, "%Y-%m-%d %H:%M:%S UTC")}
              </p>
            <% end %>
          </div>

          <div style="display: flex; gap: 0.5rem;">
            <%= if @qbo_integration && @qbo_integration.status == "connected" do %>
              <button
                class="btn btn-primary"
                phx-click="qbo_sync"
                disabled={@qbo_syncing}
              >
                <%= if @qbo_syncing, do: "Syncing...", else: "Sync Now" %>
              </button>
              <%= if @can_write do %>
                <button
                  class="btn btn-danger"
                  phx-click="qbo_disconnect"
                  data-confirm="Disconnect QuickBooks? This won't delete synced data."
                >
                  Disconnect
                </button>
              <% end %>
            <% else %>
              <.link href={~p"/auth/quickbooks/connect?company_id=#{@company.id}"} class="btn btn-primary">
                Connect to QuickBooks
              </.link>
            <% end %>
          </div>
        </div>

        <%= if @qbo_sync_result do %>
          <div style="margin-top: 1rem; padding: 0.75rem; border-radius: 4px; border: 1px solid var(--color-border); background: var(--color-bg-alt, #f8f9fa);">
            <%= case @qbo_sync_result do %>
              <% {:ok, results} -> %>
                <strong style="color: #00994d;">Sync completed</strong>
                <ul style="margin: 0.5rem 0 0; padding-left: 1.5rem;">
                  <li>Accounts: {format_qbo_sync_count(results.accounts)}</li>
                  <li>Journal Entries: {format_qbo_sync_count(results.journal_entries)}</li>
                </ul>
              <% {:error, reason} -> %>
                <strong style="color: #cc0000;">Sync failed</strong>
                <p style="margin: 0.25rem 0 0; color: #cc0000;">{inspect(reason)}</p>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def render_tab(%{active_tab: "comments"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-header">
        <h3 class="section-title">Comments ({length(@comments)})</h3>
      </div>

      <div class="panel">
        <div class="panel-body">
          <%= if @comments == [] do %>
            <p class="standfirst">No comments yet. Be the first to add one.</p>
          <% else %>
            <div style="display: flex; flex-direction: column; gap: 1rem;">
              <div
                :for={comment <- @comments}
                style="border-bottom: 1px solid var(--rule, #e0d9ce); padding-bottom: 0.75rem;"
              >
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.25rem;">
                  <strong>{if comment.user, do: comment.user.email, else: "Unknown"}</strong>
                  <span style="font-size: 0.85rem; color: #666;">
                    {Calendar.strftime(comment.inserted_at, "%d %b %Y %H:%M")}
                  </span>
                </div>
                <p style="margin: 0; white-space: pre-wrap;">{comment.body}</p>
                <%= if @can_admin do %>
                  <button
                    phx-click="delete_comment"
                    phx-value-id={comment.id}
                    data-confirm="Delete this comment?"
                    style="font-size: 0.8rem; color: #cc0000; background: none; border: none; cursor: pointer; padding: 0; margin-top: 0.25rem;"
                  >
                    Delete
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="panel" style="margin-top: 1rem;">
        <div class="panel-header">
          <h4>Add Comment</h4>
        </div>
        <div class="panel-body">
          <form phx-submit="save_comment">
            <div class="form-group">
              <textarea
                name="body"
                rows="3"
                placeholder="Write a comment..."
                style="width: 100%; padding: 0.5rem; border: 1px solid var(--rule, #e0d9ce); border-radius: 3px; font-family: inherit;"
                required
              >{@comment_body}</textarea>
            </div>
            <div class="form-actions" style="margin-top: 0.5rem;">
              <button type="submit" class="btn btn-primary">Post Comment</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
