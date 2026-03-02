defmodule HoldcoWeb.TransferPricingLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}
  alias Holdco.Compliance.TransferPricingStudy

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    studies = Compliance.list_transfer_pricing_studies()
    summary = Compliance.transfer_pricing_summary()

    {:ok,
     assign(socket,
       page_title: "Transfer Pricing",
       companies: companies,
       studies: studies,
       summary: summary,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    studies = Compliance.list_transfer_pricing_studies(company_id)
    summary = Compliance.transfer_pricing_summary(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       studies: studies,
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
    study = Compliance.get_transfer_pricing_study!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: study)}
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

  def handle_event("save", %{"transfer_pricing_study" => params}, socket) do
    case Compliance.create_transfer_pricing_study(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transfer pricing study added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add study")}
    end
  end

  def handle_event("update", %{"transfer_pricing_study" => params}, socket) do
    study = socket.assigns.editing_item

    case Compliance.update_transfer_pricing_study(study, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transfer pricing study updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update study")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    study = Compliance.get_transfer_pricing_study!(String.to_integer(id))

    case Compliance.delete_transfer_pricing_study(study) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transfer pricing study deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete study")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Transfer Pricing</h1>
          <p class="deck">Related party pricing studies and documentation</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Study</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Studies</div>
        <div class="metric-value">{length(@studies)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Needing Adjustment</div>
        <div class="metric-value num-negative">{@summary.needing_adjustment_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Adjustment Amount</div>
        <div class="metric-value num-negative">${format_number(@summary.total_adjustment_amount)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Methods Used</div>
        <div class="metric-value">{length(@summary.by_method)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Documentation Gaps</div>
        <div class={"metric-value #{if documentation_gaps(@studies) > 0, do: "num-negative", else: "num-positive"}"}>
          {documentation_gaps(@studies)}
        </div>
      </div>
    </div>

    <%= if @summary.by_method != [] do %>
      <div class="section">
        <div class="section-head"><h2>Summary by Method</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Method</th>
                <th class="th-num">Studies</th>
                <th class="th-num">Total Amount</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @summary.by_method do %>
                <tr>
                  <td><span class="tag tag-jade">{humanize_method(row.method)}</span></td>
                  <td class="td-num">{row.count}</td>
                  <td class="td-num">${format_number(row.total_amount || 0)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>Studies</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Study Name</th>
              <th>Company</th>
              <th>Year</th>
              <th>Related Party</th>
              <th>Type</th>
              <th>Method</th>
              <th class="th-num">Amount</th>
              <th class="th-num">AL Variance %</th>
              <th>Conclusion</th>
              <th>Doc Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for study <- @studies do %>
              <tr>
                <td class="td-name">{study.study_name}</td>
                <td>
                  <%= if study.company do %>
                    <.link navigate={~p"/companies/#{study.company.id}"} class="td-link">{study.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{study.fiscal_year}</td>
                <td>{study.related_party_name}</td>
                <td><span class="tag tag-sky">{humanize_type(study.transaction_type)}</span></td>
                <td><span class="tag tag-jade">{humanize_method(study.method)}</span></td>
                <td class="td-num">${format_number(study.transaction_amount || 0)}</td>
                <% al_var = arm_length_variance(study) %>
                <td class="td-num">
                  <%= if al_var do %>
                    <span class={"tag #{al_variance_tag(al_var)}"}>
                      {format_number(al_var)}%
                    </span>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td><span class={"tag #{conclusion_tag(study.conclusion)}"}>{humanize_conclusion(study.conclusion)}</span></td>
                <td><span class={"tag #{doc_status_tag(study.documentation_status)}"}>{humanize_doc_status(study.documentation_status)}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={study.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={study.id} class="btn btn-danger btn-sm" data-confirm="Delete this study?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @studies == [] do %>
          <div class="empty-state">
            <p>No transfer pricing studies found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Document and track related party transactions and arm's length pricing analysis.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Study</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Study", else: "Add Study"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Study Name *</label>
                <input type="text" name="transfer_pricing_study[study_name]" class="form-input"
                  value={if @editing_item, do: @editing_item.study_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="transfer_pricing_study[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Fiscal Year *</label>
                <input type="number" name="transfer_pricing_study[fiscal_year]" class="form-input"
                  value={if @editing_item, do: @editing_item.fiscal_year, else: Date.utc_today().year} required />
              </div>
              <div class="form-group">
                <label class="form-label">Related Party Name *</label>
                <input type="text" name="transfer_pricing_study[related_party_name]" class="form-input"
                  value={if @editing_item, do: @editing_item.related_party_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Transaction Type</label>
                <select name="transfer_pricing_study[transaction_type]" class="form-select">
                  <%= for t <- TransferPricingStudy.transaction_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.transaction_type == t}>{humanize_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Transaction Amount</label>
                <input type="number" name="transfer_pricing_study[transaction_amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.transaction_amount, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="transfer_pricing_study[currency]" class="form-input"
                  value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Method</label>
                <select name="transfer_pricing_study[method]" class="form-select">
                  <%= for m <- TransferPricingStudy.methods() do %>
                    <option value={m} selected={@editing_item && @editing_item.method == m}>{humanize_method(m)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Arm's Length Range Low</label>
                <input type="number" name="transfer_pricing_study[arm_length_range_low]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.arm_length_range_low, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Arm's Length Range High</label>
                <input type="number" name="transfer_pricing_study[arm_length_range_high]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.arm_length_range_high, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Tested Party Margin</label>
                <input type="number" name="transfer_pricing_study[tested_party_margin]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.tested_party_margin, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Conclusion</label>
                <select name="transfer_pricing_study[conclusion]" class="form-select">
                  <%= for c <- TransferPricingStudy.conclusions() do %>
                    <option value={c} selected={@editing_item && @editing_item.conclusion == c}>{humanize_conclusion(c)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Adjustment Needed</label>
                <input type="number" name="transfer_pricing_study[adjustment_needed]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.adjustment_needed, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Documentation Status</label>
                <select name="transfer_pricing_study[documentation_status]" class="form-select">
                  <%= for s <- TransferPricingStudy.documentation_statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.documentation_status == s}>{humanize_doc_status(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="transfer_pricing_study[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Study", else: "Add Study"}
                </button>
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

    studies = Compliance.list_transfer_pricing_studies(company_id)
    summary = Compliance.transfer_pricing_summary(company_id)
    assign(socket, studies: studies, summary: summary)
  end

  defp humanize_method("cup"), do: "CUP"
  defp humanize_method("resale_price"), do: "Resale Price"
  defp humanize_method("cost_plus"), do: "Cost Plus"
  defp humanize_method("tnmm"), do: "TNMM"
  defp humanize_method("profit_split"), do: "Profit Split"
  defp humanize_method(other), do: other || "CUP"

  defp humanize_type("goods"), do: "Goods"
  defp humanize_type("services"), do: "Services"
  defp humanize_type("ip_licensing"), do: "IP Licensing"
  defp humanize_type("financing"), do: "Financing"
  defp humanize_type("cost_sharing"), do: "Cost Sharing"
  defp humanize_type(other), do: other || "Goods"

  defp humanize_conclusion("within_range"), do: "Within Range"
  defp humanize_conclusion("below_range"), do: "Below Range"
  defp humanize_conclusion("above_range"), do: "Above Range"
  defp humanize_conclusion(other), do: other || "Within Range"

  defp conclusion_tag("within_range"), do: "tag-jade"
  defp conclusion_tag("below_range"), do: "tag-lemon"
  defp conclusion_tag("above_range"), do: "tag-lemon"
  defp conclusion_tag(_), do: "tag-jade"

  defp humanize_doc_status("not_started"), do: "Not Started"
  defp humanize_doc_status("in_progress"), do: "In Progress"
  defp humanize_doc_status("complete"), do: "Complete"
  defp humanize_doc_status("filed"), do: "Filed"
  defp humanize_doc_status(other), do: other || "Not Started"

  defp doc_status_tag("complete"), do: "tag-jade"
  defp doc_status_tag("filed"), do: "tag-jade"
  defp doc_status_tag("in_progress"), do: "tag-sky"
  defp doc_status_tag(_), do: "tag-lemon"

  defp documentation_gaps(studies) do
    Enum.count(studies, fn s ->
      s.documentation_status in [nil, "not_started", "incomplete"] or is_nil(s.documentation_status)
    end)
  end

  defp arm_length_variance(study) do
    low = study.arm_length_range_low
    high = study.arm_length_range_high
    margin = study.tested_party_margin

    if low && high && margin do
      mid = Decimal.div(Decimal.add(low, high), Decimal.new(2))

      if Decimal.gt?(mid, 0) do
        Decimal.mult(Decimal.div(Decimal.sub(margin, mid), mid), Decimal.new(100))
        |> Decimal.round(1)
        |> Decimal.to_float()
      else
        nil
      end
    else
      nil
    end
  rescue
    _ -> nil
  end

  defp al_variance_tag(pct) do
    abs_pct = abs(pct)

    cond do
      abs_pct <= 5 -> "tag-jade"
      abs_pct <= 15 -> "tag-lemon"
      true -> "tag-crimson"
    end
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

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
