defmodule HoldcoWeb.RevaluationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Portfolio}

  @fx_gain_loss_account_code "9100"
  @fx_gain_loss_account_name "FX Gain/Loss"

  @impl true
  def mount(_params, _session, socket) do
    accounts = Finance.list_accounts()
    trial_data = Finance.trial_balance()

    non_usd_accounts = build_non_usd_accounts(accounts, trial_data)
    metrics = compute_metrics(non_usd_accounts)

    {:ok,
     assign(socket,
       page_title: "Currency Revaluation",
       non_usd_accounts: non_usd_accounts,
       total_fx_gain: metrics.total_gain,
       total_fx_loss: metrics.total_loss,
       net_fx_impact: metrics.net_impact,
       fx_gain_loss_account_code: @fx_gain_loss_account_code,
       fx_gain_loss_account_name: @fx_gain_loss_account_name,
       generating: false
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("generate_reval_je", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("generate_reval_je", _params, socket) do
    non_usd = socket.assigns.non_usd_accounts
    net_impact = socket.assigns.net_fx_impact

    if net_impact == 0.0 do
      {:noreply, put_flash(socket, :info, "No FX gain/loss to record. Net impact is zero.")}
    else
      today = Date.utc_today() |> Date.to_iso8601()

      lines = build_journal_lines(non_usd)

      case create_revaluation_entry(today, lines, net_impact) do
        {:ok, _je} ->
          {:noreply,
           socket
           |> put_flash(:info, "Revaluation journal entry created successfully.")
           |> assign(generating: false)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create revaluation journal entry.")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Currency Revaluation</h1>
          <p class="deck">
            Unrealized FX gain/loss on non-USD denominated accounts at current exchange rates
          </p>
        </div>
        <%= if @can_write do %>
          <button
            phx-click="generate_reval_je"
            class="btn btn-primary"
            disabled={@net_fx_impact == 0.0}
          >
            Generate Revaluation JE
          </button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total FX Gain</div>
        <div class="metric-value num-positive">${format_number(@total_fx_gain)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total FX Loss</div>
        <div class="metric-value num-negative">${format_number(@total_fx_loss)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net FX Impact</div>
        <div class={"metric-value #{if @net_fx_impact >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(@net_fx_impact)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Non-USD Accounts</div>
        <div class="metric-value">{length(@non_usd_accounts)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>FX Exposure by Currency</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="fx-exposure-chart"
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(exposure_chart_data(@non_usd_accounts))}
          data-chart-options={
            Jason.encode!(%{
              plugins: %{legend: %{display: true, position: "top"}},
              scales: %{
                y: %{
                  beginAtZero: true,
                  title: %{display: true, text: "USD Value"}
                }
              }
            })
          }
          style="height: 300px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Account Revaluation Detail</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Code</th>
              <th>Account Name</th>
              <th>Currency</th>
              <th class="th-num">Local Balance</th>
              <th class="th-num">USD @ Historical</th>
              <th class="th-num">FX Rate</th>
              <th class="th-num">USD @ Current</th>
              <th class="th-num">FX Gain/Loss</th>
            </tr>
          </thead>
          <tbody>
            <%= for a <- @non_usd_accounts do %>
              <tr>
                <td class="td-mono">{a.code}</td>
                <td class="td-name">{a.name}</td>
                <td>
                  <span class="tag tag-ink">{a.currency}</span>
                </td>
                <td class="td-num">{format_number(a.local_balance)}</td>
                <td class="td-num">{format_number(a.usd_historical)}</td>
                <td class="td-num" style="font-size: 0.85rem;">{format_rate(a.current_rate)}</td>
                <td class="td-num">{format_number(a.usd_current)}</td>
                <td class={"td-num #{gain_loss_class(a.fx_gain_loss)}"} style="font-weight: 600;">
                  {format_signed(a.fx_gain_loss)}
                </td>
              </tr>
            <% end %>
          </tbody>
          <tfoot>
            <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
              <td colspan="4" class="td-name">Totals</td>
              <td class="td-num">{format_number(Enum.reduce(@non_usd_accounts, 0.0, fn a, acc -> acc + a.usd_historical end))}</td>
              <td></td>
              <td class="td-num">{format_number(Enum.reduce(@non_usd_accounts, 0.0, fn a, acc -> acc + a.usd_current end))}</td>
              <td class={"td-num #{gain_loss_class(@net_fx_impact)}"}>
                {format_signed(@net_fx_impact)}
              </td>
            </tr>
          </tfoot>
        </table>
        <%= if @non_usd_accounts == [] do %>
          <div class="empty-state">
            No non-USD accounts found. Accounts with currencies other than USD will appear here for revaluation.
          </div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Revaluation Notes</h2>
      </div>
      <div class="panel" style="padding: 1.5rem;">
        <p style="color: var(--muted); font-size: 0.9rem; line-height: 1.6;">
          Currency revaluation calculates unrealized FX gains and losses on non-USD denominated accounts.
          The historical rate is assumed to be the rate at which the balance was originally recorded (approximated
          as 1.0 / current_rate for initial balances). The "Generate Revaluation JE" button creates a journal entry
          debiting or crediting each account's FX difference and posting the offset to the
          <strong>{@fx_gain_loss_account_code} - {@fx_gain_loss_account_name}</strong> account.
        </p>
        <p style="color: var(--muted); font-size: 0.85rem; margin-top: 0.75rem;">
          FX rates are fetched live where available, with fallback rates for major currencies.
        </p>
      </div>
    </div>
    """
  end

  # -- Data Building --

  defp build_non_usd_accounts(accounts, trial_data) do
    # Build a lookup from account id to trial balance data
    trial_by_id = Map.new(trial_data, fn t -> {t.id, t} end)

    accounts
    |> Enum.filter(fn a -> a.currency != nil and a.currency != "" and a.currency != "USD" end)
    |> Enum.map(fn a ->
      trial = Map.get(trial_by_id, a.id)
      local_balance = if trial, do: trial.balance, else: 0.0

      current_rate = Portfolio.get_fx_rate(a.currency)

      # USD value at historical rate: the balance was recorded at some historical rate.
      # We approximate the historical rate as the inverse of the balance/USD relationship
      # at time of entry. For revaluation purposes, we treat the trial balance as the
      # historical USD value (since journal entries are typically in USD).
      usd_historical = local_balance

      # USD value at current rate: convert local balance at today's rate
      usd_current = local_balance * current_rate

      fx_gain_loss = usd_current - usd_historical

      %{
        id: a.id,
        code: a.code || "---",
        name: a.name,
        currency: a.currency,
        local_balance: local_balance,
        usd_historical: usd_historical,
        current_rate: current_rate,
        usd_current: usd_current,
        fx_gain_loss: fx_gain_loss
      }
    end)
    |> Enum.filter(fn a -> a.local_balance != 0.0 end)
    |> Enum.sort_by(fn a -> abs(a.fx_gain_loss) end, :desc)
  end

  defp compute_metrics(non_usd_accounts) do
    gains =
      non_usd_accounts
      |> Enum.filter(&(&1.fx_gain_loss > 0))
      |> Enum.reduce(0.0, fn a, acc -> acc + a.fx_gain_loss end)

    losses =
      non_usd_accounts
      |> Enum.filter(&(&1.fx_gain_loss < 0))
      |> Enum.reduce(0.0, fn a, acc -> acc + a.fx_gain_loss end)

    %{
      total_gain: gains,
      total_loss: losses,
      net_impact: gains + losses
    }
  end

  # -- Journal Entry Creation --

  defp build_journal_lines(non_usd_accounts) do
    non_usd_accounts
    |> Enum.filter(fn a -> a.fx_gain_loss != 0.0 end)
    |> Enum.map(fn a ->
      if a.fx_gain_loss > 0 do
        %{account_id: a.id, debit: a.fx_gain_loss, credit: 0.0}
      else
        %{account_id: a.id, debit: 0.0, credit: abs(a.fx_gain_loss)}
      end
    end)
  end

  defp create_revaluation_entry(date, lines, net_impact) do
    # Find or reference the FX Gain/Loss account
    fx_account = find_fx_gain_loss_account()

    offset_line =
      if net_impact > 0 do
        # Net gain: credit the FX Gain/Loss account
        %{account_id: fx_account_id(fx_account), debit: 0.0, credit: net_impact}
      else
        # Net loss: debit the FX Gain/Loss account
        %{account_id: fx_account_id(fx_account), debit: abs(net_impact), credit: 0.0}
      end

    all_lines = lines ++ [offset_line]

    Finance.create_journal_entry(%{
      date: date,
      description: "FX Revaluation - #{date}",
      status: "posted",
      lines: all_lines
    })
  end

  defp find_fx_gain_loss_account do
    Finance.list_accounts()
    |> Enum.find(fn a -> a.code == @fx_gain_loss_account_code end)
  end

  defp fx_account_id(nil), do: nil
  defp fx_account_id(account), do: account.id

  # -- Chart Data --

  defp exposure_chart_data(non_usd_accounts) do
    by_currency =
      non_usd_accounts
      |> Enum.group_by(& &1.currency)
      |> Enum.map(fn {ccy, accounts} ->
        historical = Enum.reduce(accounts, 0.0, fn a, acc -> acc + a.usd_historical end)
        current = Enum.reduce(accounts, 0.0, fn a, acc -> acc + a.usd_current end)
        gain_loss = current - historical
        %{currency: ccy, historical: historical, current: current, gain_loss: gain_loss}
      end)
      |> Enum.sort_by(&abs(&1.gain_loss), :desc)

    %{
      labels: Enum.map(by_currency, & &1.currency),
      datasets: [
        %{
          label: "USD @ Historical",
          data: Enum.map(by_currency, & &1.historical),
          backgroundColor: "#6b87a0"
        },
        %{
          label: "USD @ Current",
          data: Enum.map(by_currency, & &1.current),
          backgroundColor: "#4a8c87"
        },
        %{
          label: "FX Gain/Loss",
          data: Enum.map(by_currency, & &1.gain_loss),
          backgroundColor:
            Enum.map(by_currency, fn e ->
              if e.gain_loss >= 0, do: "#5f8f6e", else: "#b0605e"
            end)
        }
      ]
    }
  end

  # -- Formatting --

  defp gain_loss_class(value) when value > 0, do: "num-positive"
  defp gain_loss_class(value) when value < 0, do: "num-negative"
  defp gain_loss_class(_), do: ""

  defp format_signed(n) when is_float(n) and n >= 0, do: "+$#{format_number(n)}"
  defp format_signed(n) when is_float(n), do: "-$#{format_number(abs(n))}"
  defp format_signed(n) when is_integer(n) and n >= 0, do: "+$#{format_number(n)}"
  defp format_signed(n) when is_integer(n), do: "-$#{format_number(abs(n))}"
  defp format_signed(_), do: "$0"

  defp format_rate(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 4)
  defp format_rate(n) when is_integer(n), do: "#{n}.0000"
  defp format_rate(_), do: "---"

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
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
