defmodule HoldcoWeb.ComplianceLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}

  @tabs ~w(regulatory_filings licenses insurance sanctions esg fatca withholding)

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Compliance",
       tabs: @tabs,
       companies: companies,
       regulatory_filings: Compliance.list_regulatory_filings(),
       licenses: Compliance.list_regulatory_licenses(),
       insurance: Compliance.list_insurance_policies(),
       sanctions: Compliance.list_sanctions_checks(),
       esg: Compliance.list_esg_scores(),
       fatca: Compliance.list_fatca_reports(),
       withholding: Compliance.list_withholding_taxes(),
       active_tab: "regulatory_filings",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs do
    {:noreply, assign(socket, active_tab: tab, show_form: false, editing_item: nil)}
  end

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  # --- Permission Guards ---
  def handle_event("save_filing", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_filing", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_filing", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_license", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_license", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_license", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_insurance", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_insurance", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_insurance", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_sanctions", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_sanctions", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_sanctions", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_esg", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_esg", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_esg", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_fatca", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_fatca", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_fatca", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_withholding", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_withholding", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_withholding", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  # --- Filing CRUD ---
  def handle_event("save_filing", %{"regulatory_filing" => params}, socket) do
    case Compliance.create_regulatory_filing(params) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Filing added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add filing")}
    end
  end

  def handle_event("edit_filing", %{"id" => id}, socket) do
    item = Compliance.get_regulatory_filing!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_filing", %{"regulatory_filing" => params}, socket) do
    item = socket.assigns.editing_item

    case Compliance.update_regulatory_filing(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Filing updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update filing")}
    end
  end

  def handle_event("delete_filing", %{"id" => id}, socket) do
    regulatory_filing = Compliance.get_regulatory_filing!(String.to_integer(id))
    Compliance.delete_regulatory_filing(regulatory_filing)
    {:noreply, reload(socket) |> put_flash(:info, "Filing deleted")}
  end

  # --- License CRUD ---
  def handle_event("save_license", %{"regulatory_license" => params}, socket) do
    case Compliance.create_regulatory_license(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "License added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add license")}
    end
  end

  def handle_event("edit_license", %{"id" => id}, socket) do
    item = Compliance.get_regulatory_license!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_license", %{"regulatory_license" => params}, socket) do
    item = socket.assigns.editing_item

    case Compliance.update_regulatory_license(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "License updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update license")}
    end
  end

  def handle_event("delete_license", %{"id" => id}, socket) do
    regulatory_license = Compliance.get_regulatory_license!(String.to_integer(id))
    Compliance.delete_regulatory_license(regulatory_license)
    {:noreply, reload(socket) |> put_flash(:info, "License deleted")}
  end

  # --- Insurance CRUD ---
  def handle_event("save_insurance", %{"insurance_policy" => params}, socket) do
    case Compliance.create_insurance_policy(params) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Policy added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add policy")}
    end
  end

  def handle_event("edit_insurance", %{"id" => id}, socket) do
    item = Compliance.get_insurance_policy!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_insurance", %{"insurance_policy" => params}, socket) do
    item = socket.assigns.editing_item

    case Compliance.update_insurance_policy(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Policy updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update policy")}
    end
  end

  def handle_event("delete_insurance", %{"id" => id}, socket) do
    insurance_policy = Compliance.get_insurance_policy!(String.to_integer(id))
    Compliance.delete_insurance_policy(insurance_policy)
    {:noreply, reload(socket) |> put_flash(:info, "Policy deleted")}
  end

  # --- Sanctions CRUD ---
  def handle_event("save_sanctions", %{"sanctions_check" => params}, socket) do
    case Compliance.create_sanctions_check(params) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Check added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add check")}
    end
  end

  def handle_event("edit_sanctions", %{"id" => id}, socket) do
    item = Compliance.get_sanctions_check!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_sanctions", %{"sanctions_check" => params}, socket) do
    item = socket.assigns.editing_item

    case Compliance.update_sanctions_check(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Check updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update check")}
    end
  end

  def handle_event("delete_sanctions", %{"id" => id}, socket) do
    sanctions_check = Compliance.get_sanctions_check!(String.to_integer(id))
    Compliance.delete_sanctions_check(sanctions_check)
    {:noreply, reload(socket) |> put_flash(:info, "Check deleted")}
  end

  # --- ESG CRUD ---
  def handle_event("save_esg", %{"esg_score" => params}, socket) do
    case Compliance.create_esg_score(params) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Score added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add score")}
    end
  end

  def handle_event("edit_esg", %{"id" => id}, socket) do
    item = Compliance.get_esg_score!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_esg", %{"esg_score" => params}, socket) do
    item = socket.assigns.editing_item

    case Compliance.update_esg_score(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Score updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update score")}
    end
  end

  def handle_event("delete_esg", %{"id" => id}, socket) do
    esg_score = Compliance.get_esg_score!(String.to_integer(id))
    Compliance.delete_esg_score(esg_score)
    {:noreply, reload(socket) |> put_flash(:info, "Score deleted")}
  end

  # --- FATCA CRUD ---
  def handle_event("save_fatca", %{"fatca_report" => params}, socket) do
    case Compliance.create_fatca_report(params) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Report added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add report")}
    end
  end

  def handle_event("edit_fatca", %{"id" => id}, socket) do
    item = Compliance.get_fatca_report!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_fatca", %{"fatca_report" => params}, socket) do
    item = socket.assigns.editing_item

    case Compliance.update_fatca_report(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Report updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update report")}
    end
  end

  def handle_event("delete_fatca", %{"id" => id}, socket) do
    fatca_report = Compliance.get_fatca_report!(String.to_integer(id))
    Compliance.delete_fatca_report(fatca_report)
    {:noreply, reload(socket) |> put_flash(:info, "Report deleted")}
  end

  # --- Withholding CRUD ---
  def handle_event("save_withholding", %{"withholding_tax" => params}, socket) do
    case Compliance.create_withholding_tax(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Tax entry added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add tax entry")}
    end
  end

  def handle_event("edit_withholding", %{"id" => id}, socket) do
    item = Compliance.get_withholding_tax!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_withholding", %{"withholding_tax" => params}, socket) do
    item = socket.assigns.editing_item

    case Compliance.update_withholding_tax(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Tax entry updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update tax entry")}
    end
  end

  def handle_event("delete_withholding", %{"id" => id}, socket) do
    withholding_tax = Compliance.get_withholding_tax!(String.to_integer(id))
    Compliance.delete_withholding_tax(withholding_tax)
    {:noreply, reload(socket) |> put_flash(:info, "Tax entry deleted")}
  end

  defp reload(socket) do
    assign(socket,
      regulatory_filings: Compliance.list_regulatory_filings(),
      licenses: Compliance.list_regulatory_licenses(),
      insurance: Compliance.list_insurance_policies(),
      sanctions: Compliance.list_sanctions_checks(),
      esg: Compliance.list_esg_scores(),
      fatca: Compliance.list_fatca_reports(),
      withholding: Compliance.list_withholding_taxes()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Compliance</h1>
      <p class="deck">
        Regulatory filings, licenses, insurance, sanctions, ESG, FATCA, and withholding taxes
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="tabs">
      <button
        :for={tab <- @tabs}
        class={"tab #{if @active_tab == tab, do: "tab-active"}"}
        phx-click="switch_tab"
        phx-value-tab={tab}
      >
        {tab_label(tab)}
      </button>
    </div>

    <div class="tab-content">
      {render_tab(assigns)}
    </div>
    """
  end

  defp tab_label("regulatory_filings"), do: "Filings"
  defp tab_label("licenses"), do: "Licenses"
  defp tab_label("insurance"), do: "Insurance"
  defp tab_label("sanctions"), do: "Sanctions"
  defp tab_label("esg"), do: "ESG"
  defp tab_label("fatca"), do: "FATCA"
  defp tab_label("withholding"), do: "Withholding"

  # ========================
  # Regulatory Filings Tab
  # ========================
  defp render_tab(%{active_tab: "regulatory_filings"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Regulatory Filings</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Jurisdiction</th>
              <th>Type</th>
              <th>Company</th>
              <th>Due</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for rf <- @regulatory_filings do %>
              <tr>
                <td>{rf.jurisdiction}</td>
                <td>{rf.filing_type}</td>
                <td>
                  <%= if rf.company do %>
                    <.link navigate={~p"/companies/#{rf.company.id}"} class="td-link">{rf.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{rf.due_date}</td>
                <td><span class={"tag #{status_tag(rf.status)}"}>{rf.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_filing" phx-value-id={rf.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_filing" phx-value-id={rf.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <%= if @regulatory_filings == [] do %>
      <div class="empty-state">
        <p>No regulatory filings yet.</p>
        <p style="color: var(--muted); font-size: 0.9rem;">Track required filings across jurisdictions for your entities.</p>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first filing</button>
        <% end %>
      </div>
    <% end %>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Regulatory Filing</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_filing">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="regulatory_filing[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction *</label>
                <input type="text" name="regulatory_filing[jurisdiction]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Filing Type *</label>
                <input type="text" name="regulatory_filing[filing_type]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Due Date *</label>
                <input
                  type="text"
                  name="regulatory_filing[due_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  required
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Regulatory Filing</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_filing">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="regulatory_filing[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction *</label>
                <input type="text" name="regulatory_filing[jurisdiction]" class="form-input" required value={@editing_item.jurisdiction} />
              </div>
              <div class="form-group">
                <label class="form-label">Filing Type *</label>
                <input type="text" name="regulatory_filing[filing_type]" class="form-input" required value={@editing_item.filing_type} />
              </div>
              <div class="form-group">
                <label class="form-label">Due Date *</label>
                <input
                  type="text"
                  name="regulatory_filing[due_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  required
                  value={@editing_item.due_date}
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ========================
  # Licenses Tab
  # ========================
  defp render_tab(%{active_tab: "licenses"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Regulatory Licenses</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Authority</th>
              <th>Company</th>
              <th>Expiry</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for rl <- @licenses do %>
              <tr>
                <td>{rl.license_type}</td>
                <td>{rl.issuing_authority}</td>
                <td>
                  <%= if rl.company do %>
                    <.link navigate={~p"/companies/#{rl.company.id}"} class="td-link">{rl.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{rl.expiry_date}</td>
                <td><span class={"tag #{status_tag(rl.status)}"}>{rl.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_license" phx-value-id={rl.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_license" phx-value-id={rl.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <%= if @licenses == [] do %>
      <div class="empty-state">
        <p>No regulatory licenses yet.</p>
        <p style="color: var(--muted); font-size: 0.9rem;">Monitor regulatory licenses and their renewal dates.</p>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first license</button>
        <% end %>
      </div>
    <% end %>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Regulatory License</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_license">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="regulatory_license[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">License Type *</label>
                <input
                  type="text"
                  name="regulatory_license[license_type]"
                  class="form-input"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Issuing Authority *</label>
                <input
                  type="text"
                  name="regulatory_license[issuing_authority]"
                  class="form-input"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">License Number</label>
                <input type="text" name="regulatory_license[license_number]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input
                  type="text"
                  name="regulatory_license[expiry_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Regulatory License</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_license">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="regulatory_license[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">License Type *</label>
                <input
                  type="text"
                  name="regulatory_license[license_type]"
                  class="form-input"
                  required
                  value={@editing_item.license_type}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Issuing Authority *</label>
                <input
                  type="text"
                  name="regulatory_license[issuing_authority]"
                  class="form-input"
                  required
                  value={@editing_item.issuing_authority}
                />
              </div>
              <div class="form-group">
                <label class="form-label">License Number</label>
                <input type="text" name="regulatory_license[license_number]" class="form-input" value={@editing_item.license_number} />
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input
                  type="text"
                  name="regulatory_license[expiry_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  value={@editing_item.expiry_date}
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ========================
  # Insurance Tab
  # ========================
  defp render_tab(%{active_tab: "insurance"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Insurance Policies</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Provider</th>
              <th>Company</th>
              <th>Coverage</th>
              <th>Premium</th>
              <th>Expiry</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for ip <- @insurance do %>
              <tr>
                <td>{ip.policy_type}</td>
                <td class="td-name">{ip.provider}</td>
                <td>
                  <%= if ip.company do %>
                    <.link navigate={~p"/companies/#{ip.company.id}"} class="td-link">{ip.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{ip.coverage_amount} {ip.currency}</td>
                <td class="td-num">{ip.premium}</td>
                <td class="td-mono">{ip.expiry_date}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_insurance" phx-value-id={ip.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_insurance" phx-value-id={ip.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <%= if @insurance == [] do %>
      <div class="empty-state">
        <p>No insurance policies yet.</p>
        <p style="color: var(--muted); font-size: 0.9rem;">Track insurance policies, coverage amounts, and renewals.</p>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first policy</button>
        <% end %>
      </div>
    <% end %>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Insurance Policy</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_insurance">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="insurance_policy[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Policy Type *</label>
                <input type="text" name="insurance_policy[policy_type]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Provider *</label>
                <input type="text" name="insurance_policy[provider]" class="form-input" required />
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
                <label class="form-label">Expiry Date</label>
                <input
                  type="text"
                  name="insurance_policy[expiry_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Insurance Policy</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_insurance">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="insurance_policy[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Policy Type *</label>
                <input type="text" name="insurance_policy[policy_type]" class="form-input" required value={@editing_item.policy_type} />
              </div>
              <div class="form-group">
                <label class="form-label">Provider *</label>
                <input type="text" name="insurance_policy[provider]" class="form-input" required value={@editing_item.provider} />
              </div>
              <div class="form-group">
                <label class="form-label">Coverage Amount</label>
                <input
                  type="number"
                  name="insurance_policy[coverage_amount]"
                  class="form-input"
                  step="any"
                  value={@editing_item.coverage_amount}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Premium</label>
                <input type="number" name="insurance_policy[premium]" class="form-input" step="any" value={@editing_item.premium} />
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input
                  type="text"
                  name="insurance_policy[expiry_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  value={@editing_item.expiry_date}
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ========================
  # Sanctions Tab
  # ========================
  defp render_tab(%{active_tab: "sanctions"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Sanctions Checks</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name Checked</th>
              <th>Company</th>
              <th>Status</th>
              <th>Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for sc <- @sanctions do %>
              <tr>
                <td class="td-name">{sc.checked_name}</td>
                <td>
                  <%= if sc.company do %>
                    <.link navigate={~p"/companies/#{sc.company.id}"} class="td-link">{sc.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <span class={"tag #{if sc.status == "clear", do: "tag-jade", else: "tag-crimson"}"}>
                    {sc.status}
                  </span>
                </td>
                <td class="td-mono">
                  {if sc.inserted_at, do: Calendar.strftime(sc.inserted_at, "%Y-%m-%d")}
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_sanctions" phx-value-id={sc.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_sanctions" phx-value-id={sc.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <%= if @sanctions == [] do %>
      <div class="empty-state">
        <p>No sanctions checks yet.</p>
        <p style="color: var(--muted); font-size: 0.9rem;">Run and record sanctions screening checks.</p>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first check</button>
        <% end %>
      </div>
    <% end %>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Run Sanctions Check</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_sanctions">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="sanctions_check[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Name to Check *</label>
                <input type="text" name="sanctions_check[checked_name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="sanctions_check[notes]"
                  class="form-input"
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Check</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Sanctions Check</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_sanctions">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="sanctions_check[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Name to Check *</label>
                <input type="text" name="sanctions_check[checked_name]" class="form-input" required value={@editing_item.checked_name} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="sanctions_check[notes]"
                  class="form-input"
                >{@editing_item.notes}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ========================
  # ESG Tab
  # ========================
  defp render_tab(%{active_tab: "esg"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>ESG Scores</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Period</th>
              <th>Company</th>
              <th>E</th>
              <th>S</th>
              <th>G</th>
              <th>Overall</th>
              <th>Framework</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for esg <- @esg do %>
              <tr>
                <td>{esg.period}</td>
                <td>
                  <%= if esg.company do %>
                    <.link navigate={~p"/companies/#{esg.company.id}"} class="td-link">{esg.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{esg.environmental_score}</td>
                <td class="td-num">{esg.social_score}</td>
                <td class="td-num">{esg.governance_score}</td>
                <td class="td-num">{esg.overall_score}</td>
                <td>{esg.framework}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_esg" phx-value-id={esg.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_esg" phx-value-id={esg.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <%= if @esg == [] do %>
      <div class="empty-state">
        <p>No ESG scores yet.</p>
        <p style="color: var(--muted); font-size: 0.9rem;">Track environmental, social, and governance scores over time.</p>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first score</button>
        <% end %>
      </div>
    <% end %>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add ESG Score</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_esg">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="esg_score[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Period *</label>
                <input
                  type="text"
                  name="esg_score[period]"
                  class="form-input"
                  placeholder="e.g. 2025-Q1"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Environmental</label>
                <input
                  type="number"
                  name="esg_score[environmental_score]"
                  class="form-input"
                  step="any"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Social</label>
                <input type="number" name="esg_score[social_score]" class="form-input" step="any" />
              </div>
              <div class="form-group">
                <label class="form-label">Governance</label>
                <input type="number" name="esg_score[governance_score]" class="form-input" step="any" />
              </div>
              <div class="form-group">
                <label class="form-label">Overall</label>
                <input type="number" name="esg_score[overall_score]" class="form-input" step="any" />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit ESG Score</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_esg">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="esg_score[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Period *</label>
                <input
                  type="text"
                  name="esg_score[period]"
                  class="form-input"
                  placeholder="e.g. 2025-Q1"
                  required
                  value={@editing_item.period}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Environmental</label>
                <input
                  type="number"
                  name="esg_score[environmental_score]"
                  class="form-input"
                  step="any"
                  value={@editing_item.environmental_score}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Social</label>
                <input type="number" name="esg_score[social_score]" class="form-input" step="any" value={@editing_item.social_score} />
              </div>
              <div class="form-group">
                <label class="form-label">Governance</label>
                <input type="number" name="esg_score[governance_score]" class="form-input" step="any" value={@editing_item.governance_score} />
              </div>
              <div class="form-group">
                <label class="form-label">Overall</label>
                <input type="number" name="esg_score[overall_score]" class="form-input" step="any" value={@editing_item.overall_score} />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ========================
  # FATCA Tab
  # ========================
  defp render_tab(%{active_tab: "fatca"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>FATCA Reports</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Year</th>
              <th>Jurisdiction</th>
              <th>Company</th>
              <th>Type</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for fr <- @fatca do %>
              <tr>
                <td>{fr.reporting_year}</td>
                <td>{fr.jurisdiction}</td>
                <td>
                  <%= if fr.company do %>
                    <.link navigate={~p"/companies/#{fr.company.id}"} class="td-link">{fr.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>{fr.report_type}</td>
                <td><span class={"tag #{status_tag(fr.status)}"}>{fr.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_fatca" phx-value-id={fr.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_fatca" phx-value-id={fr.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <%= if @fatca == [] do %>
      <div class="empty-state">
        <p>No FATCA reports yet.</p>
        <p style="color: var(--muted); font-size: 0.9rem;">Manage FATCA and CRS reporting obligations.</p>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first report</button>
        <% end %>
      </div>
    <% end %>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add FATCA Report</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_fatca">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="fatca_report[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Reporting Year *</label>
                <input type="number" name="fatca_report[reporting_year]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction *</label>
                <input type="text" name="fatca_report[jurisdiction]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="fatca_report[report_type]"
                  class="form-select"
                ><option value="fatca">FATCA</option><option value="crs">CRS</option></select>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit FATCA Report</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_fatca">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="fatca_report[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Reporting Year *</label>
                <input type="number" name="fatca_report[reporting_year]" class="form-input" required value={@editing_item.reporting_year} />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction *</label>
                <input type="text" name="fatca_report[jurisdiction]" class="form-input" required value={@editing_item.jurisdiction} />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="fatca_report[report_type]"
                  class="form-select"
                ><option value="fatca" selected={@editing_item.report_type == "fatca"}>FATCA</option><option value="crs" selected={@editing_item.report_type == "crs"}>CRS</option></select>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ========================
  # Withholding Tab
  # ========================
  defp render_tab(%{active_tab: "withholding"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Withholding Taxes</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Payment Type</th>
              <th>From</th>
              <th>To</th>
              <th>Gross</th>
              <th>Rate</th>
              <th>Tax</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for wt <- @withholding do %>
              <tr>
                <td class="td-mono">{wt.date}</td>
                <td>{wt.payment_type}</td>
                <td>{wt.country_from}</td>
                <td>{wt.country_to}</td>
                <td class="td-num">{wt.gross_amount}</td>
                <td class="td-num">{wt.rate}%</td>
                <td class="td-num">{wt.tax_amount}</td>
                <td>
                  <%= if wt.company do %>
                    <.link navigate={~p"/companies/#{wt.company.id}"} class="td-link">{wt.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_withholding" phx-value-id={wt.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_withholding" phx-value-id={wt.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <%= if @withholding == [] do %>
      <div class="empty-state">
        <p>No withholding taxes yet.</p>
        <p style="color: var(--muted); font-size: 0.9rem;">Track withholding tax obligations on cross-border payments.</p>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first tax entry</button>
        <% end %>
      </div>
    <% end %>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Withholding Tax</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_withholding">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="withholding_tax[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Payment Type *</label>
                <input type="text" name="withholding_tax[payment_type]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Country From *</label>
                <input type="text" name="withholding_tax[country_from]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Country To *</label>
                <input type="text" name="withholding_tax[country_to]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Gross Amount *</label>
                <input
                  type="number"
                  name="withholding_tax[gross_amount]"
                  class="form-input"
                  step="any"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Rate % *</label>
                <input
                  type="number"
                  name="withholding_tax[rate]"
                  class="form-input"
                  step="any"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Amount *</label>
                <input
                  type="number"
                  name="withholding_tax[tax_amount]"
                  class="form-input"
                  step="any"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input
                  type="text"
                  name="withholding_tax[date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  required
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Withholding Tax</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_withholding">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="withholding_tax[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Payment Type *</label>
                <input type="text" name="withholding_tax[payment_type]" class="form-input" required value={@editing_item.payment_type} />
              </div>
              <div class="form-group">
                <label class="form-label">Country From *</label>
                <input type="text" name="withholding_tax[country_from]" class="form-input" required value={@editing_item.country_from} />
              </div>
              <div class="form-group">
                <label class="form-label">Country To *</label>
                <input type="text" name="withholding_tax[country_to]" class="form-input" required value={@editing_item.country_to} />
              </div>
              <div class="form-group">
                <label class="form-label">Gross Amount *</label>
                <input
                  type="number"
                  name="withholding_tax[gross_amount]"
                  class="form-input"
                  step="any"
                  required
                  value={@editing_item.gross_amount}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Rate % *</label>
                <input
                  type="number"
                  name="withholding_tax[rate]"
                  class="form-input"
                  step="any"
                  required
                  value={@editing_item.rate}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Amount *</label>
                <input
                  type="number"
                  name="withholding_tax[tax_amount]"
                  class="form-input"
                  step="any"
                  required
                  value={@editing_item.tax_amount}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input
                  type="text"
                  name="withholding_tax[date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  required
                  value={@editing_item.date}
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("completed"), do: "tag-jade"
  defp status_tag("filed"), do: "tag-jade"
  defp status_tag("pending"), do: "tag-lemon"
  defp status_tag("not_started"), do: "tag-lemon"
  defp status_tag("expired"), do: "tag-crimson"
  defp status_tag("overdue"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"
end
