defmodule HoldcoWeb.CompanyLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{
    Corporate,
    Banking,
    Assets,
    Documents,
    Compliance,
    Finance,
    Governance,
    Collaboration
  }

  @tabs ~w(overview holdings bank_accounts transactions documents governance compliance financials comments)
  @upload_dir Path.join([:code.priv_dir(:holdco), "static", "uploads"])

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Corporate.subscribe()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "comments:companies:#{id}")
    end

    company = Corporate.get_company_with_preloads!(id)
    companies = Corporate.list_companies()
    comments = Collaboration.list_comments("companies", String.to_integer(id))

    {:ok,
     socket
     |> assign(
       page_title: company.name,
       tabs: @tabs,
       company: company,
       companies: companies,
       comments: comments,
       comment_body: "",
       active_tab: "overview",
       show_form: nil
     )
     |> allow_upload(:file,
       accept: ~w(.pdf .doc .docx .xls .xlsx .png .jpg),
       max_file_size: 20_000_000
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs do
    {:noreply, assign(socket, active_tab: tab, show_form: nil)}
  end

  def handle_event("show_form", %{"form" => form}, socket) do
    {:noreply, assign(socket, show_form: form)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: nil)}
  end

  # --- Permission Guards ---
  def handle_event("save_holding", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_holding", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_bank_account", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_bank_account", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_transaction", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_transaction", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_document", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_document", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_board_meeting", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_board_meeting", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_service_provider", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_service_provider", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_key_personnel", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_key_personnel", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_beneficial_owner", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_beneficial_owner", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_tax_deadline", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_tax_deadline", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_financial", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_financial", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_insurance_policy", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_insurance_policy", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_company", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  # --- Holdings ---
  def handle_event("save_holding", %{"holding" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Assets.create_holding(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Holding added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add holding")}
    end
  end

  def handle_event("delete_holding", %{"id" => id}, socket) do
    holding = Assets.get_holding!(String.to_integer(id))
    Assets.delete_holding(holding)
    {:noreply, reload_company(socket) |> put_flash(:info, "Holding deleted")}
  end

  # --- Bank Accounts ---
  def handle_event("save_bank_account", %{"bank_account" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Banking.create_bank_account(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Bank account added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add bank account")}
    end
  end

  def handle_event("delete_bank_account", %{"id" => id}, socket) do
    bank_account = Banking.get_bank_account!(String.to_integer(id))
    Banking.delete_bank_account(bank_account)
    {:noreply, reload_company(socket) |> put_flash(:info, "Bank account deleted")}
  end

  # --- Transactions ---
  def handle_event("save_transaction", %{"transaction" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Banking.create_transaction(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Transaction added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add transaction")}
    end
  end

  def handle_event("delete_transaction", %{"id" => id}, socket) do
    transaction = Banking.get_transaction!(String.to_integer(id))
    Banking.delete_transaction(transaction)
    {:noreply, reload_company(socket) |> put_flash(:info, "Transaction deleted")}
  end

  # --- Documents ---
  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("save_document", %{"document" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Documents.create_document(params) do
      {:ok, document} ->
        process_doc_uploads(socket, document)

        {:noreply,
         reload_company(socket) |> put_flash(:info, "Document added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add document")}
    end
  end

  def handle_event("delete_document", %{"id" => id}, socket) do
    document = Documents.get_document!(String.to_integer(id))
    Documents.delete_document(document)
    {:noreply, reload_company(socket) |> put_flash(:info, "Document deleted")}
  end

  # --- Board Meetings ---
  def handle_event("save_board_meeting", %{"board_meeting" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Governance.create_board_meeting(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Board meeting added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add board meeting")}
    end
  end

  def handle_event("delete_board_meeting", %{"id" => id}, socket) do
    bm = Governance.get_board_meeting!(id)
    Governance.delete_board_meeting(bm)
    {:noreply, reload_company(socket) |> put_flash(:info, "Board meeting deleted")}
  end

  # --- Service Providers ---
  def handle_event("save_service_provider", %{"service_provider" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Corporate.create_service_provider(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Service provider added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add service provider")}
    end
  end

  def handle_event("delete_service_provider", %{"id" => id}, socket) do
    sp = Corporate.get_service_provider!(id)
    Corporate.delete_service_provider(sp)
    {:noreply, reload_company(socket) |> put_flash(:info, "Service provider deleted")}
  end

  # --- Key Personnel ---
  def handle_event("save_key_personnel", %{"key_personnel" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Corporate.create_key_personnel(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Key personnel added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add key personnel")}
    end
  end

  def handle_event("delete_key_personnel", %{"id" => id}, socket) do
    kp = Corporate.get_key_personnel!(id)
    Corporate.delete_key_personnel(kp)
    {:noreply, reload_company(socket) |> put_flash(:info, "Key personnel deleted")}
  end

  # --- Beneficial Owners ---
  def handle_event("save_beneficial_owner", %{"beneficial_owner" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Corporate.create_beneficial_owner(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Beneficial owner added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add beneficial owner")}
    end
  end

  def handle_event("delete_beneficial_owner", %{"id" => id}, socket) do
    bo = Corporate.get_beneficial_owner!(id)
    Corporate.delete_beneficial_owner(bo)
    {:noreply, reload_company(socket) |> put_flash(:info, "Beneficial owner deleted")}
  end

  # --- Tax Deadlines ---
  def handle_event("save_tax_deadline", %{"tax_deadline" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_tax_deadline(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Tax deadline added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add tax deadline")}
    end
  end

  def handle_event("delete_tax_deadline", %{"id" => id}, socket) do
    tax_deadline = Compliance.get_tax_deadline!(String.to_integer(id))
    Compliance.delete_tax_deadline(tax_deadline)
    {:noreply, reload_company(socket) |> put_flash(:info, "Tax deadline deleted")}
  end

  # --- Financials ---
  def handle_event("save_financial", %{"financial" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Finance.create_financial(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Financial record added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add financial record")}
    end
  end

  def handle_event("delete_financial", %{"id" => id}, socket) do
    financial = Finance.get_financial!(String.to_integer(id))
    Finance.delete_financial(financial)
    {:noreply, reload_company(socket) |> put_flash(:info, "Financial record deleted")}
  end

  # --- Insurance Policies ---
  def handle_event("save_insurance_policy", %{"insurance_policy" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_insurance_policy(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Insurance policy added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add insurance policy")}
    end
  end

  def handle_event("delete_insurance_policy", %{"id" => id}, socket) do
    insurance_policy = Compliance.get_insurance_policy!(String.to_integer(id))
    Compliance.delete_insurance_policy(insurance_policy)
    {:noreply, reload_company(socket) |> put_flash(:info, "Insurance policy deleted")}
  end

  # --- Company Update ---
  def handle_event("update_company", %{"company" => params}, socket) do
    case Corporate.update_company(socket.assigns.company, params) do
      {:ok, _} -> {:noreply, reload_company(socket) |> put_flash(:info, "Company updated")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to update company")}
    end
  end

  # --- Comments ---
  def handle_event("save_comment", %{"body" => body}, socket) do
    attrs = %{
      user_id: socket.assigns.current_scope.user.id,
      entity_type: "companies",
      entity_id: socket.assigns.company.id,
      body: String.trim(body)
    }

    case Collaboration.create_comment(attrs) do
      {:ok, _} ->
        comments = Collaboration.list_comments("companies", socket.assigns.company.id)
        {:noreply, assign(socket, comments: comments, comment_body: "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to post comment")}
    end
  end

  def handle_event("delete_comment", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_comment", %{"id" => id}, socket) do
    comment = Holdco.Repo.get!(Holdco.Collaboration.Comment, String.to_integer(id))
    Collaboration.delete_comment(comment)
    comments = Collaboration.list_comments("companies", socket.assigns.company.id)
    {:noreply, assign(socket, comments: comments) |> put_flash(:info, "Comment deleted")}
  end

  @impl true
  def handle_info({:new_comment, _comment}, socket) do
    comments = Collaboration.list_comments("companies", socket.assigns.company.id)
    {:noreply, assign(socket, comments: comments)}
  end

  def handle_info(_, socket), do: {:noreply, reload_company(socket)}

  defp reload_company(socket) do
    company = Corporate.get_company_with_preloads!(socket.assigns.company.id)
    assign(socket, company: company, page_title: company.name)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>{@company.name}</h1>
          <p class="deck">
            {@company.country}
            {if @company.category, do: " / #{@company.category}"}
            {if @company.is_holding, do: " / Holding"}
          </p>
        </div>
        <.link navigate={~p"/companies"} class="btn btn-secondary">Back to Companies</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="tabs">
      <button
        :for={
          tab <-
            ~w(overview holdings bank_accounts transactions documents governance compliance financials comments)
        }
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

  defp tab_label("overview"), do: "Overview"
  defp tab_label("holdings"), do: "Holdings"
  defp tab_label("bank_accounts"), do: "Bank Accounts"
  defp tab_label("transactions"), do: "Transactions"
  defp tab_label("documents"), do: "Documents"
  defp tab_label("governance"), do: "Governance"
  defp tab_label("compliance"), do: "Compliance"
  defp tab_label("financials"), do: "Financials"
  defp tab_label("comments"), do: "Comments"

  defp render_tab(%{active_tab: "overview"} = assigns) do
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

  defp render_tab(%{active_tab: "holdings"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Holdings</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="holding">
            Add Holding
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
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
            <%= for h <- @company.asset_holdings do %>
              <tr>
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
        <%= if @company.asset_holdings == [] do %>
          <div class="empty-state">No holdings for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  defp render_tab(%{active_tab: "bank_accounts"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Bank Accounts</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="bank_account">
            Add Account
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
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
            <%= for ba <- @company.bank_accounts do %>
              <tr>
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
        <%= if @company.bank_accounts == [] do %>
          <div class="empty-state">No bank accounts for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  defp render_tab(%{active_tab: "transactions"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Transactions</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="transaction">
            Add Transaction
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
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
            <%= for tx <- @company.transactions do %>
              <tr>
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
        <%= if @company.transactions == [] do %>
          <div class="empty-state">No transactions for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  defp render_tab(%{active_tab: "documents"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Documents</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="document">
            Add Document
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>URL</th>
              <th>Notes</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for doc <- @company.documents do %>
              <tr>
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
        <%= if @company.documents == [] do %>
          <div class="empty-state">No documents for this company.</div>
        <% end %>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  defp render_tab(%{active_tab: "governance"} = assigns) do
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
              <th>Date</th>
              <th>Type</th>
              <th>Status</th>
              <th>Notes</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for bm <- @company.board_meetings do %>
              <tr>
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
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Investor</th>
                <th>Round</th>
                <th>Shares</th>
                <th>Amount</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              <%= for ct <- @company.cap_table do %>
                <tr>
                  <td class="td-name">{ct.investor}</td>
                  <td>{ct.round_name}</td>
                  <td class="td-num">{ct.shares}</td>
                  <td class="td-num">{ct.amount_invested} {ct.currency}</td>
                  <td class="td-mono">{ct.date}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Resolutions</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Title</th>
                <th>Type</th>
                <th>Date</th>
                <th>Passed</th>
              </tr>
            </thead>
            <tbody>
              <%= for res <- @company.resolutions do %>
                <tr>
                  <td class="td-name">{res.title}</td>
                  <td>{res.resolution_type}</td>
                  <td class="td-mono">{res.date}</td>
                  <td>{if res.passed, do: "Yes", else: "No"}</td>
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
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Counterparty</th>
                <th>Value</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for deal <- @company.deals do %>
                <tr>
                  <td>{deal.deal_type}</td>
                  <td class="td-name">{deal.counterparty}</td>
                  <td class="td-num">{deal.value} {deal.currency}</td>
                  <td><span class="tag tag-ink">{deal.status}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Joint Ventures</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Partner</th>
                <th>Ownership</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for jv <- @company.joint_ventures do %>
                <tr>
                  <td class="td-name">{jv.name}</td>
                  <td>{jv.partner}</td>
                  <td class="td-num">{jv.ownership_pct}%</td>
                  <td><span class={"tag #{status_tag(jv.status)}"}>{jv.status}</span></td>
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
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Grantor</th>
              <th>Grantee</th>
              <th>Scope</th>
              <th>Start</th>
              <th>End</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <%= for poa <- @company.powers_of_attorney do %>
              <tr>
                <td class="td-name">{poa.grantor}</td>
                <td>{poa.grantee}</td>
                <td>{poa.scope}</td>
                <td class="td-mono">{poa.start_date}</td>
                <td class="td-mono">{poa.end_date}</td>
                <td><span class={"tag #{status_tag(poa.status)}"}>{poa.status}</span></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    {render_inline_form(assigns)}
    """
  end

  defp render_tab(%{active_tab: "compliance"} = assigns) do
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
              <th>Jurisdiction</th>
              <th>Description</th>
              <th>Due Date</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for td <- @company.tax_deadlines do %>
              <tr>
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
                <th>Type</th>
                <th>Provider</th>
                <th>Coverage</th>
                <th>Expiry</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for ip <- @company.insurance_policies do %>
                <tr>
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
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Jurisdiction</th>
                <th>Type</th>
                <th>Due</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for rf <- @company.regulatory_filings do %>
                <tr>
                  <td>{rf.jurisdiction}</td>
                  <td>{rf.filing_type}</td>
                  <td class="td-mono">{rf.due_date}</td>
                  <td><span class={"tag #{deadline_status_tag(rf.status)}"}>{rf.status}</span></td>
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
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Authority</th>
                <th>Expiry</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for rl <- @company.regulatory_licenses do %>
                <tr>
                  <td>{rl.license_type}</td>
                  <td>{rl.issuing_authority}</td>
                  <td class="td-mono">{rl.expiry_date}</td>
                  <td><span class={"tag #{status_tag(rl.status)}"}>{rl.status}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>ESG Scores</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Period</th>
                <th>E</th>
                <th>S</th>
                <th>G</th>
                <th>Overall</th>
              </tr>
            </thead>
            <tbody>
              <%= for esg <- @company.esg_scores do %>
                <tr>
                  <td>{esg.period}</td>
                  <td class="td-num">{esg.environmental_score}</td>
                  <td class="td-num">{esg.social_score}</td>
                  <td class="td-num">{esg.governance_score}</td>
                  <td class="td-num">{esg.overall_score}</td>
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

  defp render_tab(%{active_tab: "financials"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Financials</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form" phx-value-form="financial">
            Add Period
          </button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Period</th>
              <th class="th-num">Revenue</th>
              <th class="th-num">Expenses</th>
              <th class="th-num">Net</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for f <- @company.financials do %>
              <tr>
                <td class="td-mono">{f.period}</td>
                <td class="td-num num-positive">{f.revenue}</td>
                <td class="td-num num-negative">{f.expenses}</td>
                <td class={"td-num #{if (f.revenue || 0) - (f.expenses || 0) >= 0, do: "num-positive", else: "num-negative"}"}>
                  {(f.revenue || 0) - (f.expenses || 0)}
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
        <%= if @company.financials == [] do %>
          <div class="empty-state">No financial records yet.</div>
        <% end %>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Liabilities</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Creditor</th>
                <th class="th-num">Principal</th>
                <th>Rate</th>
                <th>Maturity</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for l <- @company.liabilities do %>
                <tr>
                  <td>{l.liability_type}</td>
                  <td class="td-name">{l.creditor}</td>
                  <td class="td-num">{l.principal} {l.currency}</td>
                  <td class="td-num">{l.interest_rate}%</td>
                  <td class="td-mono">{l.maturity_date}</td>
                  <td><span class={"tag #{status_tag(l.status)}"}>{l.status}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Dividends</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Recipient</th>
                <th class="th-num">Amount</th>
                <th>Type</th>
              </tr>
            </thead>
            <tbody>
              <%= for d <- @company.dividends do %>
                <tr>
                  <td class="td-mono">{d.date}</td>
                  <td class="td-name">{d.recipient}</td>
                  <td class="td-num">{d.amount} {d.currency}</td>
                  <td>{d.dividend_type}</td>
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

  defp render_tab(%{active_tab: "comments"} = assigns) do
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

  # --- Inline form rendering ---

  defp render_inline_form(%{show_form: nil} = assigns), do: ~H""

  defp render_inline_form(%{show_form: "holding"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Holding</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "bank_account"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Bank Account</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "transaction"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Transaction</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "document"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Document</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "board_meeting"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Board Meeting</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "key_personnel"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Key Personnel</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "beneficial_owner"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Beneficial Owner</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "service_provider"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Service Provider</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "tax_deadline"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Tax Deadline</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "financial"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Financial Period</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(%{show_form: "insurance_policy"} = assigns) do
    ~H"""
    <div class="modal-overlay" phx-click="close_form">
      <div class="modal" phx-click-away="close_form">
        <div class="modal-header">
          <h3>Add Insurance Policy</h3>
        </div>
        <div class="modal-body">
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

  defp render_inline_form(assigns), do: ~H""

  # --- Tag helpers ---

  defp kyc_tag("approved"), do: "tag-jade"
  defp kyc_tag("in_progress"), do: "tag-lemon"
  defp kyc_tag("rejected"), do: "tag-crimson"
  defp kyc_tag(_), do: "tag-ink"

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("winding_down"), do: "tag-lemon"
  defp status_tag("dissolved"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"

  defp meeting_status_tag("completed"), do: "tag-jade"
  defp meeting_status_tag("scheduled"), do: "tag-lemon"
  defp meeting_status_tag("cancelled"), do: "tag-crimson"
  defp meeting_status_tag(_), do: "tag-ink"

  defp deadline_status_tag("completed"), do: "tag-jade"
  defp deadline_status_tag("filed"), do: "tag-jade"
  defp deadline_status_tag("pending"), do: "tag-lemon"
  defp deadline_status_tag("overdue"), do: "tag-crimson"
  defp deadline_status_tag(_), do: "tag-ink"

  # --- File Upload Helpers ---
  defp process_doc_uploads(socket, document) do
    File.mkdir_p!(@upload_dir)

    consume_uploaded_entries(socket, :file, fn %{path: tmp_path}, entry ->
      unique_name = unique_file_name(entry.client_name)
      dest = Path.join(@upload_dir, unique_name)
      File.cp!(tmp_path, dest)

      Documents.create_document_upload(%{
        document_id: document.id,
        file_path: dest,
        file_name: entry.client_name,
        file_size: entry.client_size,
        content_type: entry.client_type
      })

      {:ok, unique_name}
    end)
  end

  defp unique_file_name(original_name) do
    ext = Path.extname(original_name)
    base = Path.basename(original_name, ext)
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "#{base}_#{timestamp}_#{random}#{ext}"
  end

  defp humanize_upload_error(:too_large), do: "File is too large (max 20 MB)"
  defp humanize_upload_error(:too_many_files), do: "Too many files"
  defp humanize_upload_error(:not_accepted), do: "File type not accepted"
  defp humanize_upload_error(err), do: "Upload error: #{inspect(err)}"
end
