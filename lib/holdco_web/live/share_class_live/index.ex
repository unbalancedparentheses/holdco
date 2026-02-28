defmodule HoldcoWeb.ShareClassLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Corporate
  alias Holdco.Corporate.ShareClass

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    share_classes = Corporate.list_share_classes()

    {:ok,
     assign(socket,
       page_title: "Share Classes",
       companies: companies,
       share_classes: share_classes,
       cap_table: [],
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    share_classes = Corporate.list_share_classes(company_id)
    cap_table = if company_id, do: Corporate.cap_table(company_id), else: []
    {:noreply, assign(socket, selected_company_id: id, share_classes: share_classes, cap_table: cap_table)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    sc = Corporate.get_share_class!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: sc)}
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

  def handle_event("save", %{"share_class" => params}, socket) do
    case Corporate.create_share_class(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Share class added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add share class")}
    end
  end

  def handle_event("update", %{"share_class" => params}, socket) do
    sc = socket.assigns.editing_item

    case Corporate.update_share_class(sc, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Share class updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update share class")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    sc = Corporate.get_share_class!(String.to_integer(id))

    case Corporate.delete_share_class(sc) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Share class deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete share class")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Share Classes & Cap Table</h1>
          <p class="deck">Manage share classes and view capitalization table</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Share Class</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @cap_table != [] do %>
      <div class="section">
        <div class="section-head"><h2>Cap Table</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Class</th><th>Code</th><th class="th-num">Outstanding</th><th class="th-num">Ownership %</th><th>Voting/Share</th><th>Dividend Pref</th></tr>
            </thead>
            <tbody>
              <%= for row <- @cap_table do %>
                <tr>
                  <td class="td-name">{row.share_class.name}</td>
                  <td><span class="tag tag-sky">{row.share_class.class_code}</span></td>
                  <td class="td-num">{format_number(row.share_class.shares_outstanding)}</td>
                  <td class="td-num">{row.ownership_pct}%</td>
                  <td class="td-num">{format_number(row.share_class.voting_rights_per_share)}</td>
                  <td>{humanize(row.share_class.dividend_preference || "none")}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Share Classes</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th><th>Code</th><th>Company</th><th class="th-num">Authorized</th>
              <th class="th-num">Issued</th><th class="th-num">Outstanding</th><th class="th-num">Par Value</th>
              <th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for sc <- @share_classes do %>
              <tr>
                <td class="td-name">{sc.name}</td>
                <td><span class="tag tag-sky">{sc.class_code}</span></td>
                <td>{if sc.company, do: sc.company.name, else: "---"}</td>
                <td class="td-num">{format_number(sc.shares_authorized)}</td>
                <td class="td-num">{format_number(sc.shares_issued)}</td>
                <td class="td-num">{format_number(sc.shares_outstanding)}</td>
                <td class="td-num">{if sc.par_value, do: "#{sc.currency} #{sc.par_value}", else: "---"}</td>
                <td><span class={"tag #{status_tag(sc.status)}"}>{humanize(sc.status)}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={sc.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={sc.id} class="btn btn-danger btn-sm" data-confirm="Delete this share class?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @share_classes == [] do %>
          <div class="empty-state">
            <p>No share classes found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Share Class</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Share Class", else: "Add Share Class"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="share_class[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="share_class[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Class Code *</label>
                <input type="text" name="share_class[class_code]" class="form-input" value={if @editing_item, do: @editing_item.class_code, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Shares Authorized</label>
                <input type="number" name="share_class[shares_authorized]" class="form-input" step="any" value={if @editing_item, do: @editing_item.shares_authorized, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Shares Issued</label>
                <input type="number" name="share_class[shares_issued]" class="form-input" step="any" value={if @editing_item, do: @editing_item.shares_issued, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Shares Outstanding</label>
                <input type="number" name="share_class[shares_outstanding]" class="form-input" step="any" value={if @editing_item, do: @editing_item.shares_outstanding, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Par Value</label>
                <input type="number" name="share_class[par_value]" class="form-input" step="any" value={if @editing_item, do: @editing_item.par_value, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="share_class[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Voting Rights/Share</label>
                <input type="number" name="share_class[voting_rights_per_share]" class="form-input" step="any" value={if @editing_item, do: @editing_item.voting_rights_per_share, else: "1"} />
              </div>
              <div class="form-group">
                <label class="form-label">Dividend Preference</label>
                <select name="share_class[dividend_preference]" class="form-select">
                  <%= for dp <- ShareClass.dividend_preferences() do %>
                    <option value={dp} selected={@editing_item && @editing_item.dividend_preference == dp}>{humanize(dp)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Liquidation Preference</label>
                <input type="number" name="share_class[liquidation_preference]" class="form-input" step="any" value={if @editing_item, do: @editing_item.liquidation_preference, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Convertible</label>
                <select name="share_class[is_convertible]" class="form-select">
                  <option value="false" selected={!(@editing_item && @editing_item.is_convertible)}>No</option>
                  <option value="true" selected={@editing_item && @editing_item.is_convertible}>Yes</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Conversion Ratio</label>
                <input type="number" name="share_class[conversion_ratio]" class="form-input" step="any" value={if @editing_item, do: @editing_item.conversion_ratio, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Redeemable</label>
                <select name="share_class[is_redeemable]" class="form-select">
                  <option value="false" selected={!(@editing_item && @editing_item.is_redeemable)}>No</option>
                  <option value="true" selected={@editing_item && @editing_item.is_redeemable}>Yes</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="share_class[status]" class="form-select">
                  <%= for s <- ShareClass.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="share_class[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Share Class"}</button>
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
    company_id = case socket.assigns.selected_company_id do
      "" -> nil
      id -> String.to_integer(id)
    end

    share_classes = Corporate.list_share_classes(company_id)
    cap_table = if company_id, do: Corporate.cap_table(company_id), else: []
    assign(socket, share_classes: share_classes, cap_table: cap_table)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("retired"), do: "tag-rose"
  defp status_tag(_), do: ""

  defp format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(_), do: "---"
end
