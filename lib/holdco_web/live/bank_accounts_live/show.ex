defmodule HoldcoWeb.BankAccountsLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate, Portfolio, Integrations, Documents, AI}
  alias Holdco.Banking.{StatementParser, StatementImport}
  alias Holdco.Money

  @upload_dir Path.join([:code.priv_dir(:holdco), "static", "uploads"])

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    account = Banking.get_bank_account!(String.to_integer(id))
    company = if account.company_id, do: Corporate.get_company!(account.company_id), else: nil

    transactions =
      Banking.list_transactions()
      |> Enum.filter(&(&1.company_id == account.company_id && &1.currency == account.currency))

    inflow =
      transactions
      |> Enum.filter(&(&1.transaction_type == "credit"))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, Money.to_decimal(tx.amount)) end)

    outflow =
      transactions
      |> Enum.filter(&(&1.transaction_type == "debit"))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, Money.abs(Money.to_decimal(tx.amount))) end)

    net = Money.sub(inflow, outflow)

    usd_balance = Portfolio.to_usd(account.balance, account.currency)

    monthly_data =
      transactions
      |> Enum.group_by(fn tx -> String.slice(to_string(tx.date), 0, 7) end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.take(-12)

    {:ok,
     socket
     |> assign(
       page_title: account.bank_name,
       account: account,
       company: company,
       transactions: transactions,
       inflow: inflow,
       outflow: outflow,
       net: net,
       usd_balance: usd_balance,
       monthly_data: monthly_data,
       import_state: :idle,
       parsed_transactions: [],
       import_error: nil,
       import_result: nil,
       raw_statement: nil,
       raw_file_name: nil,
       statement_analysis: nil,
       analysis_loading: false,
       feed_config: load_feed_config(account.id),
       feed_transactions: load_feed_transactions(account.id),
       stored_statements: load_stored_statements(account.company_id)
     )
     |> allow_upload(:statement, accept: ~w(.csv), max_entries: 1, max_file_size: 10_000_000)}
  end

  # -- Import events --

  @impl true
  def handle_event("open_import", _, socket) do
    {:noreply, assign(socket, import_state: :uploading, import_error: nil)}
  end

  def handle_event("close_import", _, socket) do
    {:noreply, assign(socket, import_state: :idle, import_error: nil, parsed_transactions: [], import_result: nil)}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("parse_statement", _params, socket) do
    socket = assign(socket, import_state: :parsing, import_error: nil)

    result =
      consume_uploaded_entries(socket, :statement, fn %{path: path}, entry ->
        content = File.read!(path)
        {:ok, {content, entry.client_name}}
      end)

    case result do
      [{content, file_name}] ->
        case StatementParser.parse(content, file_name) do
          {:ok, txns} ->
            indexed = txns |> Enum.with_index() |> Enum.map(fn {t, i} -> Map.put(t, :idx, i) end)

            {:noreply,
             assign(socket,
               import_state: :reviewing,
               parsed_transactions: indexed,
               raw_statement: content,
               raw_file_name: file_name
             )}

          {:error, reason} ->
            {:noreply, assign(socket, import_state: :uploading, import_error: reason)}
        end

      _ ->
        {:noreply, assign(socket, import_state: :uploading, import_error: "No file uploaded")}
    end
  end

  def handle_event("remove_row", %{"idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    txns = Enum.reject(socket.assigns.parsed_transactions, &(&1.idx == idx))
    {:noreply, assign(socket, parsed_transactions: txns)}
  end

  def handle_event("confirm_import", _, socket) do
    account = socket.assigns.account
    txns = socket.assigns.parsed_transactions

    {:ok, result} = StatementImport.import_transactions(account, txns)

    # Store original statement file
    store_statement_file(socket.assigns.raw_statement, socket.assigns.raw_file_name, account)

    # Kick off AI analysis if configured
    analysis_loading = AI.configured?() and txns != []

    if analysis_loading do
      send(self(), {:run_analysis, txns, account})
    end

    {:noreply,
     assign(socket,
       import_state: :done,
       import_result: result,
       raw_statement: nil,
       analysis_loading: analysis_loading,
       feed_config: load_feed_config(account.id),
       feed_transactions: load_feed_transactions(account.id),
       stored_statements: load_stored_statements(account.company_id)
     )}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:run_analysis, txns, account}, socket) do
    analysis = analyze_statement(txns, account)
    {:noreply, assign(socket, statement_analysis: analysis, analysis_loading: false)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>{@account.bank_name}</h1>
          <p class="deck">Bank account details</p>
        </div>
        <div style="display: flex; gap: 0.5rem;">
          <button class="btn btn-primary" phx-click="open_import">Import Statement</button>
          <.link navigate={~p"/bank-accounts"} class="btn btn-secondary">Back to Accounts</.link>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Balance</div>
        <div class="metric-value">${format_number(@account.balance || 0)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Currency</div>
        <div class="metric-value">{@account.currency}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Type</div>
        <div class="metric-value">{@account.account_type}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Inflow</div>
        <div class="metric-value num-positive">{format_currency(@inflow, @account.currency)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Outflow</div>
        <div class="metric-value num-negative">{format_currency(@outflow, @account.currency)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Flow</div>
        <div class={"metric-value #{if Money.negative?(@net), do: "num-negative", else: "num-positive"}"}>{format_currency(@net, @account.currency)}</div>
      </div>
      <%= if @account.currency != "USD" do %>
        <div class="metric-cell">
          <div class="metric-label">USD Equivalent</div>
          <div class="metric-value">${format_number(@usd_balance)}</div>
        </div>
      <% end %>
    </div>

    <%= if @import_state != :idle do %>
      {render_import_dialog(assigns)}
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>Account Details</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <dl class="detail-list">
          <div class="detail-row">
            <dt>Bank Name</dt>
            <dd>{@account.bank_name}</dd>
          </div>
          <div class="detail-row">
            <dt>Account Number</dt>
            <dd class="td-mono">{@account.account_number || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>IBAN</dt>
            <dd class="td-mono">{@account.iban || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>SWIFT</dt>
            <dd class="td-mono">{@account.swift || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>Company</dt>
            <dd>
              <%= if @company do %>
                <.link navigate={~p"/companies/#{@company.id}"} class="td-link">{@company.name}</.link>
              <% else %>
                ---
              <% end %>
            </dd>
          </div>
        </dl>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Monthly Flow</h2></div>
      <div class="panel">
        <div id="bank-monthly-chart" phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(monthly_chart_data(@monthly_data))}
          data-chart-options={Jason.encode!(%{plugins: %{legend: %{position: "top"}}, scales: %{y: %{beginAtZero: true}}})}
          style="height: 260px;">
          <canvas></canvas>
        </div>
      </div>
    </div>

    <%= if @feed_transactions != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Imported Bank Feed</h2>
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <span class="count">{length(@feed_transactions)} transactions</span>
            <%= if @feed_config do %>
              <.link navigate={~p"/bank-reconciliation?config_id=#{@feed_config.id}"} class="btn btn-sm btn-secondary">
                Reconcile
              </.link>
            <% end %>
          </div>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Description</th>
                <th class="th-num">Amount</th>
                <th>Currency</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for ft <- Enum.take(@feed_transactions, 20) do %>
                <tr>
                  <td class="td-mono">{ft.date}</td>
                  <td class="td-name">{ft.description}</td>
                  <td class={"td-num #{if Decimal.negative?(ft.amount), do: "num-negative", else: "num-positive"}"}>
                    {Decimal.round(ft.amount, 2)}
                  </td>
                  <td>{ft.currency}</td>
                  <td>
                    <%= if ft.is_matched do %>
                      <span class="tag tag-jade">Matched</span>
                    <% else %>
                      <span class="tag tag-lemon">Unmatched</span>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if length(@feed_transactions) > 20 do %>
            <div style="padding: 0.5rem 1rem; font-size: 0.85rem; color: #666;">
              Showing 20 of {length(@feed_transactions)} — <.link navigate={~p"/bank-reconciliation?config_id=#{@feed_config && @feed_config.id}"} class="td-link">view all in reconciliation</.link>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @stored_statements != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Imported Statements</h2>
          <span class="count">{length(@stored_statements)} files</span>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Statement</th>
                <th>File</th>
                <th class="th-num">Size</th>
              </tr>
            </thead>
            <tbody>
              <%= for doc <- @stored_statements do %>
                <tr>
                  <td class="td-mono">{Calendar.strftime(doc.inserted_at, "%Y-%m-%d")}</td>
                  <td class="td-name">{doc.name}</td>
                  <td>
                    <%= for upload <- doc.uploads do %>
                      <.link navigate={~p"/downloads/#{upload.id}"} class="td-link" style="font-size: 0.85rem;">
                        {upload.file_name}
                      </.link>
                    <% end %>
                  </td>
                  <td class="td-num" style="font-size: 0.85rem;">
                    <%= for upload <- doc.uploads do %>
                      {format_bytes(upload.file_size)}
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>Related Transactions</h2>
        <span class="count">{length(@transactions)}</span>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Type</th>
              <th>Description</th>
              <th class="th-num">Amount</th>
              <th>Currency</th>
            </tr>
          </thead>
          <tbody>
            <%= for tx <- @transactions do %>
              <tr>
                <td class="td-mono">{tx.date}</td>
                <td><span class="tag tag-ink">{tx.transaction_type}</span></td>
                <td class="td-name">{tx.description}</td>
                <td class={"td-num #{if tx.transaction_type == "debit" or Money.negative?(tx.amount), do: "num-negative", else: "num-positive"}"}>
                  {format_currency(tx.amount, tx.currency)}
                </td>
                <td>{tx.currency}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @transactions == [] do %>
          <div class="empty-state">No transactions for this company.</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_import_dialog(%{import_state: :uploading} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_import">
      <div class="dialog-panel" phx-click="noop" style="max-width: 500px;">
        <div class="dialog-header">
          <h3>Import Bank Statement</h3>
        </div>
        <div class="dialog-body">
          <%= if @import_error do %>
            <div style="padding: 0.75rem; background: #ffebee; border-radius: 4px; color: #c62828; margin-bottom: 1rem;">
              {@import_error}
            </div>
          <% end %>
          <form id="upload-form" phx-submit="parse_statement" phx-change="validate_upload">
            <div class="form-group">
              <label class="form-label">Bank statement file (CSV)</label>
              <.live_file_input upload={@uploads.statement} />
            </div>
            <%= for entry <- @uploads.statement.entries do %>
              <div style="margin: 0.5rem 0; font-size: 0.9rem;">
                {entry.client_name} ({format_bytes(entry.client_size)})
                <%= for err <- upload_errors(@uploads.statement, entry) do %>
                  <span style="color: #c62828; margin-left: 0.5rem;">{upload_error_to_string(err)}</span>
                <% end %>
              </div>
            <% end %>
            <div class="form-actions" style="margin-top: 1rem;">
              <button type="submit" class="btn btn-primary" disabled={@uploads.statement.entries == []}>
                Parse Statement
              </button>
              <button type="button" phx-click="close_import" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp render_import_dialog(%{import_state: :parsing} = assigns) do
    ~H"""
    <div class="dialog-overlay">
      <div class="dialog-panel" style="max-width: 500px; text-align: center; padding: 2rem;">
        <div style="font-size: 1.2rem; margin-bottom: 0.5rem;">Parsing statement...</div>
        <p style="color: #666;">Analyzing your bank statement</p>
      </div>
    </div>
    """
  end

  defp render_import_dialog(%{import_state: :reviewing} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_import">
      <div class="dialog-panel" phx-click="noop" style="max-width: 800px;">
        <div class="dialog-header">
          <h3>Review Transactions ({length(@parsed_transactions)})</h3>
        </div>
        <div class="dialog-body">
          <%= if @import_error do %>
            <div style="padding: 0.75rem; background: #ffebee; border-radius: 4px; color: #c62828; margin-bottom: 1rem;">
              {@import_error}
            </div>
          <% end %>
          <div style="max-height: 400px; overflow-y: auto;">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Description</th>
                  <th class="th-num">Amount</th>
                  <th>Currency</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <%= for txn <- @parsed_transactions do %>
                  <tr>
                    <td class="td-mono">{txn.date}</td>
                    <td class="td-name">{txn.description}</td>
                    <td class={"td-num #{if Decimal.negative?(txn.amount), do: "num-negative", else: "num-positive"}"}>
                      {Decimal.round(txn.amount, 2)}
                    </td>
                    <td>{txn.currency}</td>
                    <td>
                      <button phx-click="remove_row" phx-value-idx={txn.idx} class="btn btn-danger btn-sm">
                        Remove
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <div class="form-actions" style="margin-top: 1rem;">
            <button phx-click="confirm_import" class="btn btn-primary" disabled={@parsed_transactions == []}>
              Import {length(@parsed_transactions)} Transactions
            </button>
            <button phx-click="close_import" class="btn btn-secondary">Cancel</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_import_dialog(%{import_state: :done} = assigns) do
    ~H"""
    <div class="dialog-overlay" phx-click="close_import">
      <div class="dialog-panel" phx-click="noop" style="max-width: 650px;">
        <div class="dialog-header">
          <h3>Import Complete</h3>
        </div>
        <div class="dialog-body">
          <div style="padding: 1rem; background: #e8f5e9; border-radius: 4px; color: #2e7d32; margin-bottom: 1rem;">
            <div style="font-size: 1.1rem; font-weight: 600; margin-bottom: 0.5rem;">
              Successfully imported!
            </div>
            <ul style="margin: 0; padding-left: 1.25rem;">
              <li>{@import_result.imported} transactions imported</li>
              <li>{@import_result.duplicates} duplicates skipped</li>
              <li>{@import_result.matched} auto-matched with book transactions</li>
            </ul>
            <div style="margin-top: 0.5rem; font-size: 0.85rem; color: #558b2f;">
              Original statement saved to Documents.
            </div>
          </div>
          <%= if @analysis_loading do %>
            <div style="padding: 1rem; background: #f3f4f6; border-radius: 4px; margin-bottom: 1rem;">
              <div style="color: #666; font-style: italic;">Analyzing statement with AI...</div>
            </div>
          <% end %>
          <%= if @statement_analysis do %>
            <div style="padding: 1rem; background: #f3f4f6; border-radius: 4px; margin-bottom: 1rem;">
              <div style="font-weight: 600; margin-bottom: 0.5rem; font-size: 0.9rem;">AI Analysis</div>
              <div style="white-space: pre-wrap; font-size: 0.85rem; line-height: 1.5;">{@statement_analysis}</div>
            </div>
          <% end %>
          <div class="form-actions">
            <.link navigate={~p"/bank-reconciliation?config_id=#{@import_result.feed_config_id}"} class="btn btn-primary">
              Go to Reconciliation
            </.link>
            <button phx-click="close_import" class="btn btn-secondary">Close</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp store_statement_file(nil, _, _), do: :ok

  defp store_statement_file(content, file_name, account) do
    File.mkdir_p!(@upload_dir)

    ext = Path.extname(file_name || ".csv")
    base = Path.basename(file_name || "statement", ext)
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    unique_name = "#{base}_#{timestamp}_#{random}#{ext}"
    dest = Path.join(@upload_dir, unique_name)

    File.write!(dest, content)

    doc_name = "Bank Statement - #{account.bank_name} - #{Date.utc_today()}"

    case Documents.create_document(%{
           name: doc_name,
           doc_type: "bank_statement",
           company_id: account.company_id,
           notes: "Imported from #{file_name}"
         }) do
      {:ok, doc} ->
        Documents.create_document_upload(%{
          document_id: doc.id,
          file_path: dest,
          file_name: file_name,
          file_size: byte_size(content),
          content_type: "text/csv",
          storage_backend: "local"
        })

      _ ->
        :ok
    end
  end

  defp analyze_statement(txns, account) do
    total_in =
      txns
      |> Enum.filter(&Decimal.positive?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn t, acc -> Decimal.add(acc, t.amount) end)

    total_out =
      txns
      |> Enum.reject(&Decimal.positive?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn t, acc -> Decimal.add(acc, Decimal.abs(t.amount)) end)

    summary =
      txns
      |> Enum.map(fn t ->
        "#{t.date} | #{t.description} | #{Decimal.to_string(t.amount)} #{t.currency}"
      end)
      |> Enum.join("\n")

    prompt = """
    Analyze this bank statement for #{account.bank_name} (#{account.currency}).
    Total inflows: #{Decimal.to_string(total_in)}, Total outflows: #{Decimal.to_string(total_out)}, #{length(txns)} transactions.

    Transactions:
    #{summary}

    Provide a concise analysis (max 300 words):
    1. **Spending patterns**: Top 3-4 expense categories you can identify from descriptions
    2. **Unusual transactions**: Any amounts that stand out as unusually large or irregular
    3. **Cash flow summary**: Net position and trend (if dates span multiple weeks/months)
    4. **Suggestions**: Any actionable observations (e.g., "recurring charges that could be consolidated")

    Be specific — reference actual transaction descriptions and amounts. No generic advice.
    """

    messages = [%{role: "user", content: prompt}]

    case AI.chat(messages, system_prompt: "You are a financial analyst reviewing bank statements. Be concise and specific.") do
      {:ok, response} -> response
      {:error, _} -> nil
    end
  end

  defp load_stored_statements(nil), do: []

  defp load_stored_statements(company_id) do
    import Ecto.Query

    Holdco.Repo.all(
      from(d in Documents.Document,
        where: d.company_id == ^company_id and d.doc_type == "bank_statement",
        order_by: [desc: d.inserted_at],
        limit: 10,
        preload: [:uploads]
      )
    )
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  defp upload_error_to_string(:too_large), do: "File too large (max 10MB)"
  defp upload_error_to_string(:not_accepted), do: "Only CSV files accepted"
  defp upload_error_to_string(:too_many_files), do: "Only one file at a time"
  defp upload_error_to_string(err), do: inspect(err)

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(0) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 0)) |> :erlang.float_to_binary(decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp format_currency(nil, _currency), do: "0"

  defp format_currency(amount, currency) do
    sign = if Money.negative?(amount), do: "-", else: ""
    "#{sign}#{format_number(Money.abs(amount))} #{currency}"
  end

  defp load_feed_config(bank_account_id) do
    import Ecto.Query
    alias Holdco.Integrations.BankFeedConfig

    Holdco.Repo.one(
      from(bfc in BankFeedConfig,
        where: bfc.bank_account_id == ^bank_account_id and bfc.provider == "csv_import",
        limit: 1
      )
    )
  end

  defp load_feed_transactions(bank_account_id) do
    case load_feed_config(bank_account_id) do
      nil -> []
      config -> Integrations.list_bank_feed_transactions(config.id)
    end
  end

  defp monthly_chart_data(monthly_data) do
    labels = Enum.map(monthly_data, &elem(&1, 0))

    credits =
      Enum.map(monthly_data, fn {_month, txs} ->
        txs
        |> Enum.filter(&(&1.transaction_type == "credit"))
        |> Enum.reduce(0, fn tx, acc -> acc + Money.to_float(tx.amount) end)
      end)

    debits =
      Enum.map(monthly_data, fn {_month, txs} ->
        txs
        |> Enum.filter(&(&1.transaction_type == "debit"))
        |> Enum.reduce(0, fn tx, acc -> acc + abs(Money.to_float(tx.amount)) end)
      end)

    %{
      labels: labels,
      datasets: [
        %{label: "Inflow", data: credits, backgroundColor: "rgba(95, 143, 110, 0.7)"},
        %{label: "Outflow", data: debits, backgroundColor: "rgba(176, 96, 94, 0.7)"}
      ]
    }
  end
end
