defmodule HoldcoWeb.CompanyLive.ShowForms do
  @moduledoc false
  use Phoenix.Component

  import HoldcoWeb.CompanyLive.ShowHelpers, only: [humanize_upload_error: 1]

  def render_inline_form(%{show_form: nil} = assigns), do: ~H""

  def render_inline_form(%{show_form: "holding"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Position</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_holding">
            <div class="form-group">
              <label class="form-label">Asset *</label>
              <input type="text" name="holding[asset]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Ticker</label>
              <input type="text" name="holding[ticker]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Quantity</label>
              <input type="number" name="holding[quantity]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Unit</label>
              <input type="text" name="holding[unit]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Asset Type</label>
              <select name="holding[asset_type]" class="form-select">
                <option value="stock">Stock</option>
                <option value="etf">ETF</option>
                <option value="crypto">Crypto</option>
                <option value="commodity">Commodity</option>
                <option value="bond">Bond</option>
                <option value="real_estate">Real Estate</option>
                <option value="private_equity">Private Equity</option>
                <option value="fund">Fund</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="holding[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "bank_account"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Bank Account</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_bank_account">
            <div class="form-group">
              <label class="form-label">Bank Name *</label>
              <input type="text" name="bank_account[bank_name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Account Number</label>
              <input type="text" name="bank_account[account_number]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">IBAN</label>
              <input type="text" name="bank_account[iban]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">SWIFT</label>
              <input type="text" name="bank_account[swift]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="bank_account[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-group">
              <label class="form-label">Account Type</label>
              <select name="bank_account[account_type]" class="form-select">
                <option value="operating">Operating</option>
                <option value="savings">Savings</option>
                <option value="escrow">Escrow</option>
                <option value="trust">Trust</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Balance</label>
              <input
                type="number"
                name="bank_account[balance]"
                class="form-input"
                step="any"
                value="0"
              />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "transaction"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Transaction</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_transaction">
            <div class="form-group">
              <label class="form-label">Date *</label>
              <input
                type="text"
                name="transaction[date]"
                class="form-input"
                placeholder="YYYY-MM-DD"
                required
              />
            </div>
            <div class="form-group">
              <label class="form-label">Type *</label>
              <input type="text" name="transaction[transaction_type]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Amount *</label>
              <input type="number" name="transaction[amount]" class="form-input" step="any" required />
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="transaction[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <input type="text" name="transaction[description]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Counterparty</label>
              <input type="text" name="transaction[counterparty]" class="form-input" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "document"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Document</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_document" phx-change="validate_upload">
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="document[name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Type</label>
              <input type="text" name="document[doc_type]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">URL</label>
              <input type="text" name="document[url]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label><textarea
                name="document[notes]"
                class="form-input"
              ></textarea>
            </div>
            <div class="form-group">
              <label class="form-label">Attach Files</label>
              <.live_file_input upload={@uploads.file} />
              <%= for entry <- @uploads.file.entries do %>
                <div style="margin-top: 0.5rem; font-size: 0.875rem;">
                  <span>{entry.client_name}</span>
                  <progress
                    value={entry.progress}
                    max="100"
                    style="width: 100px; margin-left: 0.5rem;"
                  >
                    {entry.progress}%
                  </progress>
                  <%= for err <- upload_errors(@uploads.file, entry) do %>
                    <span style="color: var(--danger);">&mdash; {humanize_upload_error(err)}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "board_meeting"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Board Meeting</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_board_meeting">
            <div class="form-group">
              <label class="form-label">Scheduled Date *</label>
              <input
                type="text"
                name="board_meeting[scheduled_date]"
                class="form-input"
                placeholder="YYYY-MM-DD"
                required
              />
            </div>
            <div class="form-group">
              <label class="form-label">Meeting Type</label>
              <select name="board_meeting[meeting_type]" class="form-select">
                <option value="regular">Regular</option>
                <option value="special">Special</option>
                <option value="annual">Annual</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label><textarea
                name="board_meeting[notes]"
                class="form-input"
              ></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "key_personnel"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Key Personnel</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_key_personnel">
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="key_personnel[name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Title</label>
              <input type="text" name="key_personnel[title]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Email</label>
              <input type="email" name="key_personnel[email]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Phone</label>
              <input type="text" name="key_personnel[phone]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Department</label>
              <input type="text" name="key_personnel[department]" class="form-input" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "beneficial_owner"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Beneficial Owner</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_beneficial_owner">
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="beneficial_owner[name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Nationality</label>
              <input type="text" name="beneficial_owner[nationality]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Ownership %</label>
              <input
                type="number"
                name="beneficial_owner[ownership_pct]"
                class="form-input"
                step="any"
                min="0"
                max="100"
              />
            </div>
            <div class="form-group">
              <label class="form-label">Control Type</label>
              <select name="beneficial_owner[control_type]" class="form-select">
                <option value="direct">Direct</option>
                <option value="indirect">Indirect</option>
              </select>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "service_provider"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Service Provider</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_service_provider">
            <div class="form-group">
              <label class="form-label">Role *</label>
              <input type="text" name="service_provider[role]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="service_provider[name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Firm</label>
              <input type="text" name="service_provider[firm]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Email</label>
              <input type="email" name="service_provider[email]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Phone</label>
              <input type="text" name="service_provider[phone]" class="form-input" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "tax_deadline"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Tax Deadline</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_tax_deadline">
            <div class="form-group">
              <label class="form-label">Jurisdiction *</label>
              <input type="text" name="tax_deadline[jurisdiction]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Description *</label>
              <input type="text" name="tax_deadline[description]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Due Date *</label>
              <input
                type="text"
                name="tax_deadline[due_date]"
                class="form-input"
                placeholder="YYYY-MM-DD"
                required
              />
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label><textarea
                name="tax_deadline[notes]"
                class="form-input"
              ></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "financial"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Financial Period</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_financial">
            <div class="form-group">
              <label class="form-label">Period *</label>
              <input
                type="text"
                name="financial[period]"
                class="form-input"
                placeholder="e.g. 2025-Q1"
                required
              />
            </div>
            <div class="form-group">
              <label class="form-label">Revenue</label>
              <input type="number" name="financial[revenue]" class="form-input" step="any" value="0" />
            </div>
            <div class="form-group">
              <label class="form-label">Expenses</label>
              <input type="number" name="financial[expenses]" class="form-input" step="any" value="0" />
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="financial[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label><textarea
                name="financial[notes]"
                class="form-input"
              ></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "insurance_policy"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Insurance Policy</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_insurance_policy">
            <div class="form-group">
              <label class="form-label">Policy Type *</label>
              <input type="text" name="insurance_policy[policy_type]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Provider *</label>
              <input type="text" name="insurance_policy[provider]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Policy Number</label>
              <input type="text" name="insurance_policy[policy_number]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Coverage Amount</label>
              <input
                type="number"
                name="insurance_policy[coverage_amount]"
                class="form-input"
                step="any"
              />
            </div>
            <div class="form-group">
              <label class="form-label">Premium</label>
              <input type="number" name="insurance_policy[premium]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="insurance_policy[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-group">
              <label class="form-label">Expiry Date</label>
              <input
                type="text"
                name="insurance_policy[expiry_date]"
                class="form-input"
                placeholder="YYYY-MM-DD"
              />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "account"} = assigns) do
    accounts = assigns.company.accounts || []
    assigns = assign(assigns, acct_list: accounts, account_types: ~w(asset liability equity revenue expense))

    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Account</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_account">
            <div class="form-group">
              <label class="form-label">Code *</label>
              <input type="text" name="account[code]" class="form-input" placeholder="e.g. 1000" required />
            </div>
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="account[name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Type *</label>
              <select name="account[account_type]" class="form-select" required>
                <option value="">Select type</option>
                <%= for t <- @account_types do %>
                  <option value={t}>{String.capitalize(t)}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Parent Account</label>
              <select name="account[parent_id]" class="form-select">
                <option value="">None (top-level)</option>
                <%= for a <- @acct_list do %>
                  <option value={a.id}>{a.code} — {a.name}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="account[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "journal_entry"} = assigns) do
    accounts = assigns.company.accounts || []
    assigns = assign(assigns, acct_list: accounts)

    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop" style="max-width: 700px;">
        <div class="dialog-header">
          <h3>New Journal Entry</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_journal_entry">
            <div style="display: grid; grid-template-columns: 1fr 1fr 2fr; gap: 0.75rem;">
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input type="date" name="entry[date]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Reference</label>
                <input type="text" name="entry[reference]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Description *</label>
                <input type="text" name="entry[description]" class="form-input" required />
              </div>
            </div>

            <h4 style="margin: 1rem 0 0.5rem;">Lines</h4>
            <table style="width: 100%; font-size: 0.9rem;">
              <thead>
                <tr>
                  <th>Account</th>
                  <th style="width: 120px;">Debit</th>
                  <th style="width: 120px;">Credit</th>
                  <th style="width: 120px;">Notes</th>
                </tr>
              </thead>
              <tbody>
                <%= for i <- 0..(@je_line_count - 1) do %>
                  <tr>
                    <td>
                      <select name={"lines[#{i}][account_id]"} class="form-select" style="font-size: 0.85rem;">
                        <option value="">Select account</option>
                        <%= for a <- @acct_list do %>
                          <option value={a.id}>{a.code} — {a.name}</option>
                        <% end %>
                      </select>
                    </td>
                    <td>
                      <input type="number" name={"lines[#{i}][debit]"} class="form-input" step="any" value="0" style="font-size: 0.85rem;" />
                    </td>
                    <td>
                      <input type="number" name={"lines[#{i}][credit]"} class="form-input" step="any" value="0" style="font-size: 0.85rem;" />
                    </td>
                    <td>
                      <input type="text" name={"lines[#{i}][notes]"} class="form-input" style="font-size: 0.85rem;" />
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <button type="button" phx-click="add_je_line" class="btn btn-secondary btn-sm" style="margin-top: 0.5rem;">
              + Add Line
            </button>

            <div class="form-actions" style="margin-top: 1rem;">
              <button type="submit" class="btn btn-primary">Create Entry</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "cap_table"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Cap Table Entry</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_cap_table">
            <div class="form-group">
              <label class="form-label">Investor *</label>
              <input type="text" name="cap_table[investor]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Round Name</label>
              <input type="text" name="cap_table[round_name]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Shares</label>
              <input type="number" name="cap_table[shares]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Amount Invested</label>
              <input type="number" name="cap_table[amount_invested]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Date</label>
              <input type="text" name="cap_table[date]" class="form-input" placeholder="YYYY-MM-DD" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "resolution"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Resolution</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_resolution">
            <div class="form-group">
              <label class="form-label">Title *</label>
              <input type="text" name="resolution[title]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Date *</label>
              <input type="text" name="resolution[date]" class="form-input" placeholder="YYYY-MM-DD" required />
            </div>
            <div class="form-group">
              <label class="form-label">Type</label>
              <select name="resolution[resolution_type]" class="form-select">
                <option value="ordinary">Ordinary</option>
                <option value="special">Special</option>
              </select>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "deal"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Deal</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_deal">
            <div class="form-group">
              <label class="form-label">Counterparty *</label>
              <input type="text" name="deal[counterparty]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Deal Type</label>
              <select name="deal[deal_type]" class="form-select">
                <option value="acquisition">Acquisition</option>
                <option value="divestiture">Divestiture</option>
                <option value="merger">Merger</option>
                <option value="investment">Investment</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Value</label>
              <input type="number" name="deal[value]" class="form-input" step="any" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "jv"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Joint Venture</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_jv">
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="jv[name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Partner *</label>
              <input type="text" name="jv[partner]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Ownership %</label>
              <input type="number" name="jv[ownership_pct]" class="form-input" step="any" value="50" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "poa"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Power of Attorney</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_poa">
            <div class="form-group">
              <label class="form-label">Grantor *</label>
              <input type="text" name="poa[grantor]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Grantee *</label>
              <input type="text" name="poa[grantee]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Scope</label>
              <input type="text" name="poa[scope]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Start Date</label>
              <input type="text" name="poa[start_date]" class="form-input" placeholder="YYYY-MM-DD" />
            </div>
            <div class="form-group">
              <label class="form-label">End Date</label>
              <input type="text" name="poa[end_date]" class="form-input" placeholder="YYYY-MM-DD" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "equity_plan"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Equity Plan</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_equity_plan">
            <div class="form-group">
              <label class="form-label">Plan Name *</label>
              <input type="text" name="equity_plan[plan_name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Total Pool</label>
              <input type="number" name="equity_plan[total_pool]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Vesting Schedule</label>
              <input type="text" name="equity_plan[vesting_schedule]" class="form-input" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "filing"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Regulatory Filing</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_filing">
            <div class="form-group">
              <label class="form-label">Jurisdiction *</label>
              <input type="text" name="filing[jurisdiction]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Filing Type *</label>
              <input type="text" name="filing[filing_type]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Due Date *</label>
              <input type="text" name="filing[due_date]" class="form-input" placeholder="YYYY-MM-DD" required />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "license"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Regulatory License</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_license">
            <div class="form-group">
              <label class="form-label">License Type *</label>
              <input type="text" name="license[license_type]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Issuing Authority *</label>
              <input type="text" name="license[issuing_authority]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">License Number</label>
              <input type="text" name="license[license_number]" class="form-input" />
            </div>
            <div class="form-group">
              <label class="form-label">Expiry Date</label>
              <input type="text" name="license[expiry_date]" class="form-input" placeholder="YYYY-MM-DD" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "esg"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add ESG Score</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_esg">
            <div class="form-group">
              <label class="form-label">Period *</label>
              <input type="text" name="esg[period]" class="form-input" placeholder="e.g. 2025" required />
            </div>
            <div class="form-group">
              <label class="form-label">Environmental Score</label>
              <input type="number" name="esg[environmental_score]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Social Score</label>
              <input type="number" name="esg[social_score]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Governance Score</label>
              <input type="number" name="esg[governance_score]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Overall Score</label>
              <input type="number" name="esg[overall_score]" class="form-input" step="any" />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "sanctions"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Sanctions Check</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_sanctions">
            <div class="form-group">
              <label class="form-label">Name to Check *</label>
              <input type="text" name="sanctions[checked_name]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label><textarea
                name="sanctions[notes]"
                class="form-input"
              ></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "fatca"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add FATCA Report</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_fatca">
            <div class="form-group">
              <label class="form-label">Reporting Year *</label>
              <input type="number" name="fatca[reporting_year]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Jurisdiction *</label>
              <input type="text" name="fatca[jurisdiction]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Report Type</label>
              <select name="fatca[report_type]" class="form-select">
                <option value="fatca">FATCA</option>
                <option value="crs">CRS</option>
              </select>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "withholding"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Withholding Tax</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_withholding">
            <div class="form-group">
              <label class="form-label">Payment Type *</label>
              <input type="text" name="withholding[payment_type]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Country From *</label>
              <input type="text" name="withholding[country_from]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Country To *</label>
              <input type="text" name="withholding[country_to]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Gross Amount *</label>
              <input type="number" name="withholding[gross_amount]" class="form-input" step="any" required />
            </div>
            <div class="form-group">
              <label class="form-label">Rate % *</label>
              <input type="number" name="withholding[rate]" class="form-input" step="any" required />
            </div>
            <div class="form-group">
              <label class="form-label">Tax Amount *</label>
              <input type="number" name="withholding[tax_amount]" class="form-input" step="any" required />
            </div>
            <div class="form-group">
              <label class="form-label">Date *</label>
              <input type="text" name="withholding[date]" class="form-input" placeholder="YYYY-MM-DD" required />
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "liability"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Liability</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_liability">
            <div class="form-group">
              <label class="form-label">Liability Type *</label>
              <input type="text" name="liability[liability_type]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Creditor *</label>
              <input type="text" name="liability[creditor]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Principal *</label>
              <input type="number" name="liability[principal]" class="form-input" step="any" required />
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="liability[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-group">
              <label class="form-label">Interest Rate %</label>
              <input type="number" name="liability[interest_rate]" class="form-input" step="any" />
            </div>
            <div class="form-group">
              <label class="form-label">Maturity Date</label>
              <input type="text" name="liability[maturity_date]" class="form-input" placeholder="YYYY-MM-DD" />
            </div>
            <div class="form-group">
              <label class="form-label">Status</label>
              <select name="liability[status]" class="form-select">
                <option value="active">Active</option>
                <option value="paid">Paid</option>
                <option value="defaulted">Defaulted</option>
              </select>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(%{show_form: "dividend"} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Dividend</h3>
        </div>
        <div class="dialog-body">
          <form phx-submit="save_dividend">
            <div class="form-group">
              <label class="form-label">Date *</label>
              <input type="text" name="dividend[date]" class="form-input" placeholder="YYYY-MM-DD" required />
            </div>
            <div class="form-group">
              <label class="form-label">Recipient *</label>
              <input type="text" name="dividend[recipient]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Amount *</label>
              <input type="number" name="dividend[amount]" class="form-input" step="any" required />
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="dividend[currency]" class="form-input" value="USD" />
            </div>
            <div class="form-group">
              <label class="form-label">Dividend Type</label>
              <select name="dividend[dividend_type]" class="form-select">
                <option value="interim">Interim</option>
                <option value="final">Final</option>
                <option value="special">Special</option>
              </select>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Add</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_inline_form(assigns), do: ~H""
end
