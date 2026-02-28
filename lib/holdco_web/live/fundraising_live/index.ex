defmodule HoldcoWeb.FundraisingLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Fund.subscribe()
    companies = Corporate.list_companies()
    pipelines = Fund.list_fundraising_pipelines()

    {:ok,
     assign(socket,
       page_title: "Fundraising Pipeline",
       companies: companies,
       pipelines: pipelines,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       show_prospect_form: false,
       selected_pipeline: nil,
       prospect_editing: nil,
       summary: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    pipelines = Fund.list_fundraising_pipelines(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       pipelines: pipelines,
       selected_pipeline: nil,
       summary: nil
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, show_prospect_form: false, prospect_editing: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    pipeline = Fund.get_fundraising_pipeline!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: pipeline)}
  end

  def handle_event("select_pipeline", %{"id" => id}, socket) do
    pipeline = Fund.get_fundraising_pipeline!(String.to_integer(id))
    summary = Fund.pipeline_summary(pipeline.id)
    {:noreply, assign(socket, selected_pipeline: pipeline, summary: summary)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, selected_pipeline: nil, summary: nil)}
  end

  def handle_event("show_prospect_form", _, socket) do
    {:noreply, assign(socket, show_prospect_form: true, prospect_editing: nil)}
  end

  def handle_event("edit_prospect", %{"id" => id}, socket) do
    prospect = Fund.get_prospect!(String.to_integer(id))
    {:noreply, assign(socket, show_prospect_form: true, prospect_editing: prospect)}
  end

  # Permission guards
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"pipeline" => params}, socket) do
    case Fund.create_fundraising_pipeline(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Pipeline created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create pipeline")}
    end
  end

  def handle_event("update", %{"pipeline" => params}, socket) do
    pipeline = socket.assigns.editing_item

    case Fund.update_fundraising_pipeline(pipeline, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Pipeline updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update pipeline")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    pipeline = Fund.get_fundraising_pipeline!(String.to_integer(id))

    case Fund.delete_fundraising_pipeline(pipeline) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_pipeline && socket.assigns.selected_pipeline.id == pipeline.id,
            do: nil,
            else: socket.assigns.selected_pipeline

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Pipeline deleted")
         |> assign(selected_pipeline: selected, summary: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete pipeline")}
    end
  end

  def handle_event("save_prospect", %{"prospect" => params}, socket) do
    pipeline = socket.assigns.selected_pipeline
    params = Map.put(params, "pipeline_id", pipeline.id)

    case Fund.create_prospect(params) do
      {:ok, _} ->
        updated_pipeline = Fund.get_fundraising_pipeline!(pipeline.id)
        summary = Fund.pipeline_summary(pipeline.id)

        {:noreply,
         socket
         |> put_flash(:info, "Prospect added")
         |> assign(show_prospect_form: false, selected_pipeline: updated_pipeline, summary: summary, prospect_editing: nil)
         |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add prospect")}
    end
  end

  def handle_event("update_prospect", %{"prospect" => params}, socket) do
    prospect = socket.assigns.prospect_editing

    case Fund.update_prospect(prospect, params) do
      {:ok, _} ->
        pipeline = Fund.get_fundraising_pipeline!(socket.assigns.selected_pipeline.id)
        summary = Fund.pipeline_summary(pipeline.id)

        {:noreply,
         socket
         |> put_flash(:info, "Prospect updated")
         |> assign(show_prospect_form: false, selected_pipeline: pipeline, summary: summary, prospect_editing: nil)
         |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update prospect")}
    end
  end

  def handle_event("delete_prospect", %{"id" => id}, socket) do
    prospect = Fund.get_prospect!(String.to_integer(id))

    case Fund.delete_prospect(prospect) do
      {:ok, _} ->
        pipeline = Fund.get_fundraising_pipeline!(socket.assigns.selected_pipeline.id)
        summary = Fund.pipeline_summary(pipeline.id)

        {:noreply,
         socket
         |> put_flash(:info, "Prospect deleted")
         |> assign(selected_pipeline: pipeline, summary: summary)
         |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete prospect")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [
             :fundraising_pipelines_created,
             :fundraising_pipelines_updated,
             :fundraising_pipelines_deleted,
             :prospects_created,
             :prospects_updated,
             :prospects_deleted
           ] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Fundraising Pipeline</h1>
          <p class="deck">Track fund raising progress, prospects, and commitments</p>
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
            <button class="btn btn-primary" phx-click="show_form">New Pipeline</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Pipelines</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Fund Name</th>
              <th>Company</th>
              <th class="th-num">Target</th>
              <th class="th-num">Raised</th>
              <th>Status</th>
              <th>First Close</th>
              <th>Final Close</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @pipelines do %>
              <tr>
                <td class="td-name">{p.fund_name}</td>
                <td>
                  <%= if p.company do %>
                    <.link navigate={~p"/companies/#{p.company.id}"} class="td-link">{p.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">${format_number(p.target_amount)}</td>
                <td class="td-num">${format_number(p.amount_raised)}</td>
                <td><span class={"tag #{pipeline_status_tag(p.status)}"}>{p.status}</span></td>
                <td class="td-mono">{p.first_close_date || "-"}</td>
                <td class="td-mono">{p.final_close_date || "-"}</td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="select_pipeline" phx-value-id={p.id} class="btn btn-secondary btn-sm">View</button>
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={p.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Delete this pipeline?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @pipelines == [] do %>
          <div class="empty-state">
            <p>No fundraising pipelines found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Create First Pipeline</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @selected_pipeline && @summary do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>{@selected_pipeline.fund_name} - Prospect Tracker</h2>
          <div style="display: flex; gap: 0.5rem;">
            <%= if @can_write do %>
              <button phx-click="show_prospect_form" class="btn btn-primary btn-sm">Add Prospect</button>
            <% end %>
            <button phx-click="close_detail" class="btn btn-secondary btn-sm">Close</button>
          </div>
        </div>

        <%!-- Pipeline summary --%>
        <div class="panel" style="margin-bottom: 1rem; padding: 1rem;">
          <div style="display: flex; gap: 2rem; flex-wrap: wrap;">
            <div>
              <strong>Target:</strong> ${format_number(@summary.target_amount)}
            </div>
            <div>
              <strong>Committed:</strong> ${format_number(@summary.total_committed)}
            </div>
            <div>
              <strong>Progress:</strong> {Decimal.to_string(@summary.progress_pct)}%
            </div>
            <div>
              <strong>Committed Count:</strong> {@summary.committed_count}
            </div>
          </div>
        </div>

        <%!-- Funnel visualization --%>
        <div class="panel" style="margin-bottom: 1rem; padding: 1rem;">
          <h3 style="margin-bottom: 0.5rem;">Funnel</h3>
          <div style="display: flex; gap: 1rem; flex-wrap: wrap;">
            <%= for stage <- ~w(identified contacted interested committed declined) do %>
              <div style="text-align: center; min-width: 80px;">
                <div style="font-size: 1.5rem; font-weight: bold;">{Map.get(@summary.prospect_counts, stage, 0)}</div>
                <div style="font-size: 0.8rem; text-transform: capitalize;"><span class={"tag #{prospect_status_tag(stage)}"}>{stage}</span></div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Investor Name</th>
                <th>Email</th>
                <th class="th-num">Commitment</th>
                <th>Status</th>
                <th>Last Contact</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for prospect <- @selected_pipeline.prospects do %>
                <tr>
                  <td class="td-name">{prospect.investor_name}</td>
                  <td>{prospect.contact_email || "-"}</td>
                  <td class="td-num">{format_number(prospect.commitment_amount)}</td>
                  <td><span class={"tag #{prospect_status_tag(prospect.status)}"}>{prospect.status}</span></td>
                  <td class="td-mono">{prospect.last_contact_date || "-"}</td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit_prospect" phx-value-id={prospect.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete_prospect" phx-value-id={prospect.id} class="btn btn-danger btn-sm" data-confirm="Delete this prospect?">Del</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @selected_pipeline.prospects == [] do %>
            <div class="empty-state">No prospects yet for this pipeline.</div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Pipeline", else: "New Pipeline"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="pipeline[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Fund Name *</label>
                <input type="text" name="pipeline[fund_name]" class="form-input" value={if @editing_item, do: @editing_item.fund_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Target Amount *</label>
                <input type="number" name="pipeline[target_amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.target_amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Hard Cap</label>
                <input type="number" name="pipeline[hard_cap]" class="form-input" step="any" value={if @editing_item, do: @editing_item.hard_cap, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Soft Cap</label>
                <input type="number" name="pipeline[soft_cap]" class="form-input" step="any" value={if @editing_item, do: @editing_item.soft_cap, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="pipeline[status]" class="form-select">
                  <%= for s <- ~w(prospecting marketing closing final_close closed) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Management Fee Rate</label>
                <input type="number" name="pipeline[management_fee_rate]" class="form-input" step="any" value={if @editing_item, do: @editing_item.management_fee_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Carried Interest Rate</label>
                <input type="number" name="pipeline[carried_interest_rate]" class="form-input" step="any" value={if @editing_item, do: @editing_item.carried_interest_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Hurdle Rate</label>
                <input type="number" name="pipeline[hurdle_rate]" class="form-input" step="any" value={if @editing_item, do: @editing_item.hurdle_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Fund Term (Years)</label>
                <input type="number" name="pipeline[fund_term_years]" class="form-input" value={if @editing_item, do: @editing_item.fund_term_years, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">First Close Date</label>
                <input type="date" name="pipeline[first_close_date]" class="form-input" value={if @editing_item, do: @editing_item.first_close_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Final Close Date</label>
                <input type="date" name="pipeline[final_close_date]" class="form-input" value={if @editing_item, do: @editing_item.final_close_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="pipeline[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
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

    <%= if @show_prospect_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @prospect_editing, do: "Edit Prospect", else: "Add Prospect"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @prospect_editing, do: "update_prospect", else: "save_prospect"}>
              <div class="form-group">
                <label class="form-label">Investor Name *</label>
                <input type="text" name="prospect[investor_name]" class="form-input" value={if @prospect_editing, do: @prospect_editing.investor_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Contact Email</label>
                <input type="email" name="prospect[contact_email]" class="form-input" value={if @prospect_editing, do: @prospect_editing.contact_email, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Commitment Amount</label>
                <input type="number" name="prospect[commitment_amount]" class="form-input" step="any" value={if @prospect_editing, do: @prospect_editing.commitment_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="prospect[status]" class="form-select">
                  <%= for s <- ~w(identified contacted interested committed declined) do %>
                    <option value={s} selected={@prospect_editing && @prospect_editing.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Last Contact Date</label>
                <input type="date" name="prospect[last_contact_date]" class="form-input" value={if @prospect_editing, do: @prospect_editing.last_contact_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="prospect[notes]" class="form-input">{if @prospect_editing, do: @prospect_editing.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @prospect_editing, do: "Update", else: "Add"}</button>
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

    pipelines = Fund.list_fundraising_pipelines(company_id)
    assign(socket, pipelines: pipelines)
  end

  defp pipeline_status_tag("closed"), do: "tag-jade"
  defp pipeline_status_tag("final_close"), do: "tag-jade"
  defp pipeline_status_tag("closing"), do: "tag-lemon"
  defp pipeline_status_tag("marketing"), do: "tag-sky"
  defp pipeline_status_tag(_), do: "tag-sky"

  defp prospect_status_tag("committed"), do: "tag-jade"
  defp prospect_status_tag("interested"), do: "tag-lemon"
  defp prospect_status_tag("contacted"), do: "tag-sky"
  defp prospect_status_tag("declined"), do: "tag-rose"
  defp prospect_status_tag(_), do: "tag-sky"

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
