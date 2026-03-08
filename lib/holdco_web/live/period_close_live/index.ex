defmodule HoldcoWeb.PeriodCloseLive.Index do
  use HoldcoWeb, :live_view

  import Ecto.Query

  alias Holdco.{Corporate, Finance, Integrations, Repo}
  alias Holdco.Integrations.{BankFeedConfig, BankFeedTransaction}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Finance.subscribe()
      Integrations.subscribe()
    end

    companies = Corporate.list_companies()

    # Default to previous month
    today = Date.utc_today()
    first_of_month = Date.beginning_of_month(today)
    period_end = Date.add(first_of_month, -1)
    period_start = Date.beginning_of_month(period_end)

    {:ok,
     socket
     |> assign(
       page_title: "Period Close",
       companies: companies,
       period_start: Date.to_iso8601(period_start),
       period_end: Date.to_iso8601(period_end),
       checklist: []
     )
     |> load_checklist()}
  end

  @impl true
  def handle_event("change_period", %{"period_start" => ps, "period_end" => pe}, socket) do
    {:noreply,
     socket
     |> assign(period_start: ps, period_end: pe)
     |> load_checklist()}
  end

  def handle_event("quick_lock", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("quick_lock", %{"company_id" => company_id_str}, socket) do
    company_id = String.to_integer(company_id_str)
    user_id = socket.assigns.current_scope.user.id

    case Finance.lock_period(
           company_id,
           socket.assigns.period_start,
           socket.assigns.period_end,
           "month",
           user_id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Period locked")
         |> load_checklist()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to lock period")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, load_checklist(socket)}

  defp load_checklist(socket) do
    companies = socket.assigns.companies
    period_start = socket.assigns.period_start
    period_end = socket.assigns.period_end

    checklist =
      Enum.map(companies, fn company ->
        recon = reconciliation_status(company.id)
        entries = journal_entry_count(company.id, period_start, period_end)
        locked = period_locked?(company.id, period_start, period_end)

        all_reconciled = recon.total > 0 and recon.unmatched == 0
        has_entries = entries > 0

        %{
          company: company,
          recon_total: recon.total,
          recon_matched: recon.matched,
          recon_unmatched: recon.unmatched,
          all_reconciled: all_reconciled,
          journal_entries: entries,
          has_entries: has_entries,
          locked: locked,
          ready: all_reconciled and has_entries and not locked,
          done: locked
        }
      end)

    assign(socket, checklist: checklist)
  end

  defp reconciliation_status(company_id) do
    configs =
      Repo.all(
        from(bfc in BankFeedConfig,
          where: bfc.company_id == ^company_id and bfc.is_active == true
        )
      )

    config_ids = Enum.map(configs, & &1.id)

    if config_ids == [] do
      %{total: 0, matched: 0, unmatched: 0}
    else
      total =
        Repo.one(
          from(bft in BankFeedTransaction,
            where: bft.feed_config_id in ^config_ids,
            select: count(bft.id)
          )
        ) || 0

      matched =
        Repo.one(
          from(bft in BankFeedTransaction,
            where: bft.feed_config_id in ^config_ids and bft.is_matched == true,
            select: count(bft.id)
          )
        ) || 0

      %{total: total, matched: matched, unmatched: total - matched}
    end
  end

  defp journal_entry_count(company_id, period_start, period_end) do
    alias Holdco.Finance.JournalEntry

    Repo.one(
      from(je in JournalEntry,
        where:
          je.company_id == ^company_id and
            je.date >= ^period_start and
            je.date <= ^period_end,
        select: count(je.id)
      )
    ) || 0
  end

  defp period_locked?(company_id, period_start, period_end) do
    alias Holdco.Finance.PeriodLock

    Repo.exists?(
      from(pl in PeriodLock,
        where:
          pl.company_id == ^company_id and
            pl.status == "locked" and
            pl.period_start <= ^period_start and
            pl.period_end >= ^period_end
      )
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Period Close</h1>
          <p class="deck">Month-end close checklist across all entities</p>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1.5rem;">
      <form phx-change="change_period" style="display: flex; gap: 0.75rem; align-items: flex-end;">
        <div>
          <label class="form-label" style="font-size: 0.85rem;">Period Start</label>
          <input type="date" name="period_start" class="form-input" style="width: auto;" value={@period_start} />
        </div>
        <div>
          <label class="form-label" style="font-size: 0.85rem;">Period End</label>
          <input type="date" name="period_end" class="form-input" style="width: auto;" value={@period_end} />
        </div>
      </form>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Entities</div>
        <div class="metric-value">{length(@checklist)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Closed</div>
        <div class="metric-value" style="color: var(--color-jade, #2d6a4f);">
          {Enum.count(@checklist, & &1.done)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Ready to Close</div>
        <div class="metric-value" style="color: var(--color-lemon, #b8860b);">
          {Enum.count(@checklist, & &1.ready)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Needs Work</div>
        <div class="metric-value" style="color: var(--color-crimson, #c0392b);">
          {Enum.count(@checklist, &(not &1.done and not &1.ready))}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Close Checklist</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Entity</th>
              <th style="text-align: center;">Reconciliation</th>
              <th style="text-align: center;">Journal Entries</th>
              <th style="text-align: center;">Period Locked</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for item <- @checklist do %>
              <tr>
                <td class="td-name">
                  <.link navigate={~p"/companies/#{item.company.id}"} class="td-link">{item.company.name}</.link>
                </td>
                <td style="text-align: center;">
                  <%= cond do %>
                    <% item.recon_total == 0 -> %>
                      <span class="tag tag-ink">No feeds</span>
                    <% item.all_reconciled -> %>
                      <span class="tag tag-jade">{item.recon_matched}/{item.recon_total} matched</span>
                    <% true -> %>
                      <span class="tag tag-crimson">{item.recon_unmatched} unmatched</span>
                    <% end %>
                </td>
                <td style="text-align: center;">
                  <%= if item.has_entries do %>
                    <span class="tag tag-jade">{item.journal_entries} entries</span>
                  <% else %>
                    <span class="tag tag-lemon">No entries</span>
                  <% end %>
                </td>
                <td style="text-align: center;">
                  <%= if item.locked do %>
                    <span class="tag tag-jade">Locked</span>
                  <% else %>
                    <span class="tag tag-lemon">Open</span>
                  <% end %>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem; justify-content: flex-end;">
                    <%= cond do %>
                      <% item.done -> %>
                        <span style="color: var(--color-jade, #2d6a4f); font-weight: 600; font-size: 0.85rem;">Closed</span>
                      <% item.recon_unmatched > 0 -> %>
                        <.link navigate={~p"/bank-reconciliation"} class="btn btn-sm btn-secondary">Reconcile</.link>
                      <% !item.has_entries -> %>
                        <.link navigate={~p"/accounts/journal"} class="btn btn-sm btn-secondary">Post Entries</.link>
                      <% item.ready and @can_write -> %>
                        <button phx-click="quick_lock" phx-value-company_id={item.company.id} class="btn btn-sm btn-primary">
                          Lock Period
                        </button>
                      <% true -> %>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @checklist == [] do %>
          <div class="empty-state">
            <p>No companies found. Add companies first to use the close checklist.</p>
          </div>
        <% end %>
      </div>
    </div>

    <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--rule);">
      <span style="font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-faint);">Related</span>
      <div style="display: flex; gap: 1rem; margin-top: 0.5rem; flex-wrap: wrap;">
        <.link navigate={~p"/bank-reconciliation"} class="td-link" style="font-size: 0.85rem;">Bank Reconciliation</.link>
        <.link navigate={~p"/accounts/journal"} class="td-link" style="font-size: 0.85rem;">Journal Entries</.link>
        <.link navigate={~p"/period-locks"} class="td-link" style="font-size: 0.85rem;">Period Locks</.link>
        <.link navigate={~p"/consolidated"} class="td-link" style="font-size: 0.85rem;">Consolidated Financials</.link>
      </div>
    </div>
    """
  end
end
