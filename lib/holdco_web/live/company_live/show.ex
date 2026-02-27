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
    Collaboration,
    Integrations
  }

  alias Holdco.Integrations.Quickbooks

  @tabs ~w(overview holdings bank_accounts transactions documents governance compliance financials accounting integrations comments)
  @upload_dir Path.join([:code.priv_dir(:holdco), "static", "uploads"])

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Corporate.subscribe()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "comments:companies:#{id}")
    end

    {company, sub_companies} = Corporate.get_company_consolidated!(id)
    is_consolidated = sub_companies != []
    companies = Corporate.list_companies()
    comments = Collaboration.list_comments("companies", String.to_integer(id))

    qbo_integration = Integrations.get_integration("quickbooks", company.id)

    {:ok,
     socket
     |> assign(
       page_title: company.name,
       tabs: @tabs,
       company: company,
       sub_companies: sub_companies,
       is_consolidated: is_consolidated,
       companies: companies,
       comments: comments,
       comment_body: "",
       active_tab: "overview",
       show_form: nil,
       je_line_count: 2,
       qbo_integration: qbo_integration,
       qbo_syncing: false,
       qbo_sync_result: nil
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
  def handle_event("noop", _, socket), do: {:noreply, socket}

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

  def handle_event("save_account", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_account", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_journal_entry", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_journal_entry", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_company", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_cap_table", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_cap_table", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_resolution", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_resolution", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_deal", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_deal", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_jv", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_jv", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_poa", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_poa", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_equity_plan", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_equity_plan", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_filing", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_filing", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_license", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_license", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_esg", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_esg", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_sanctions", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_sanctions", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_fatca", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_fatca", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_withholding", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_withholding", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_liability", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_liability", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_dividend", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_dividend", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("qbo_disconnect", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("qbo_sync", _params, %{assigns: %{can_write: false}} = socket),
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

  # --- Cap Table ---
  def handle_event("save_cap_table", %{"cap_table" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Governance.create_cap_table_entry(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Cap table entry added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add cap table entry")}
    end
  end

  def handle_event("delete_cap_table", %{"id" => id}, socket) do
    ct = Governance.get_cap_table_entry!(id)
    Governance.delete_cap_table_entry(ct)
    {:noreply, reload_company(socket) |> put_flash(:info, "Cap table entry deleted")}
  end

  # --- Resolutions ---
  def handle_event("save_resolution", %{"resolution" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Governance.create_shareholder_resolution(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Resolution added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add resolution")}
    end
  end

  def handle_event("delete_resolution", %{"id" => id}, socket) do
    res = Governance.get_shareholder_resolution!(id)
    Governance.delete_shareholder_resolution(res)
    {:noreply, reload_company(socket) |> put_flash(:info, "Resolution deleted")}
  end

  # --- Deals ---
  def handle_event("save_deal", %{"deal" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Governance.create_deal(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Deal added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add deal")}
    end
  end

  def handle_event("delete_deal", %{"id" => id}, socket) do
    deal = Governance.get_deal!(id)
    Governance.delete_deal(deal)
    {:noreply, reload_company(socket) |> put_flash(:info, "Deal deleted")}
  end

  # --- Joint Ventures ---
  def handle_event("save_jv", %{"jv" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Governance.create_joint_venture(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Joint venture added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add joint venture")}
    end
  end

  def handle_event("delete_jv", %{"id" => id}, socket) do
    jv = Governance.get_joint_venture!(id)
    Governance.delete_joint_venture(jv)
    {:noreply, reload_company(socket) |> put_flash(:info, "Joint venture deleted")}
  end

  # --- Powers of Attorney ---
  def handle_event("save_poa", %{"poa" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Governance.create_power_of_attorney(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Power of attorney added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add power of attorney")}
    end
  end

  def handle_event("delete_poa", %{"id" => id}, socket) do
    poa = Governance.get_power_of_attorney!(id)
    Governance.delete_power_of_attorney(poa)
    {:noreply, reload_company(socket) |> put_flash(:info, "Power of attorney deleted")}
  end

  # --- Equity Plans ---
  def handle_event("save_equity_plan", %{"equity_plan" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Governance.create_equity_incentive_plan(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Equity plan added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add equity plan")}
    end
  end

  def handle_event("delete_equity_plan", %{"id" => id}, socket) do
    plan = Governance.get_equity_incentive_plan!(id)
    Governance.delete_equity_incentive_plan(plan)
    {:noreply, reload_company(socket) |> put_flash(:info, "Equity plan deleted")}
  end

  # --- Regulatory Filings ---
  def handle_event("save_filing", %{"filing" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_regulatory_filing(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Regulatory filing added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add regulatory filing")}
    end
  end

  def handle_event("delete_filing", %{"id" => id}, socket) do
    filing = Compliance.get_regulatory_filing!(String.to_integer(id))
    Compliance.delete_regulatory_filing(filing)
    {:noreply, reload_company(socket) |> put_flash(:info, "Regulatory filing deleted")}
  end

  # --- Regulatory Licenses ---
  def handle_event("save_license", %{"license" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_regulatory_license(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Regulatory license added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add regulatory license")}
    end
  end

  def handle_event("delete_license", %{"id" => id}, socket) do
    license = Compliance.get_regulatory_license!(String.to_integer(id))
    Compliance.delete_regulatory_license(license)
    {:noreply, reload_company(socket) |> put_flash(:info, "Regulatory license deleted")}
  end

  # --- ESG Scores ---
  def handle_event("save_esg", %{"esg" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_esg_score(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "ESG score added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add ESG score")}
    end
  end

  def handle_event("delete_esg", %{"id" => id}, socket) do
    esg = Compliance.get_esg_score!(String.to_integer(id))
    Compliance.delete_esg_score(esg)
    {:noreply, reload_company(socket) |> put_flash(:info, "ESG score deleted")}
  end

  # --- Sanctions Checks ---
  def handle_event("save_sanctions", %{"sanctions" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_sanctions_check(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Sanctions check added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add sanctions check")}
    end
  end

  def handle_event("delete_sanctions", %{"id" => id}, socket) do
    sc = Compliance.get_sanctions_check!(String.to_integer(id))
    Compliance.delete_sanctions_check(sc)
    {:noreply, reload_company(socket) |> put_flash(:info, "Sanctions check deleted")}
  end

  # --- FATCA Reports ---
  def handle_event("save_fatca", %{"fatca" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_fatca_report(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "FATCA report added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add FATCA report")}
    end
  end

  def handle_event("delete_fatca", %{"id" => id}, socket) do
    fatca = Compliance.get_fatca_report!(String.to_integer(id))
    Compliance.delete_fatca_report(fatca)
    {:noreply, reload_company(socket) |> put_flash(:info, "FATCA report deleted")}
  end

  # --- Withholding Taxes ---
  def handle_event("save_withholding", %{"withholding" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Compliance.create_withholding_tax(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket)
         |> put_flash(:info, "Withholding tax added")
         |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add withholding tax")}
    end
  end

  def handle_event("delete_withholding", %{"id" => id}, socket) do
    wt = Compliance.get_withholding_tax!(String.to_integer(id))
    Compliance.delete_withholding_tax(wt)
    {:noreply, reload_company(socket) |> put_flash(:info, "Withholding tax deleted")}
  end

  # --- Liabilities ---
  def handle_event("save_liability", %{"liability" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Finance.create_liability(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Liability added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add liability")}
    end
  end

  def handle_event("delete_liability", %{"id" => id}, socket) do
    liability = Finance.get_liability!(String.to_integer(id))
    Finance.delete_liability(liability)
    {:noreply, reload_company(socket) |> put_flash(:info, "Liability deleted")}
  end

  # --- Dividends ---
  def handle_event("save_dividend", %{"dividend" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)

    case Finance.create_dividend(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Dividend added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add dividend")}
    end
  end

  def handle_event("delete_dividend", %{"id" => id}, socket) do
    dividend = Finance.get_dividend!(String.to_integer(id))
    Finance.delete_dividend(dividend)
    {:noreply, reload_company(socket) |> put_flash(:info, "Dividend deleted")}
  end

  # --- QuickBooks Integration ---
  def handle_event("qbo_disconnect", _params, socket) do
    case Integrations.disconnect_integration("quickbooks", socket.assigns.company.id) do
      {:ok, _} ->
        {:noreply,
         assign(socket, qbo_integration: nil, qbo_sync_result: nil)
         |> put_flash(:info, "QuickBooks disconnected")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disconnect")}
    end
  end

  def handle_event("qbo_sync", _params, socket) do
    send(self(), :do_qbo_sync)
    {:noreply, assign(socket, qbo_syncing: true, qbo_sync_result: nil)}
  end

  # --- Accounts ---
  def handle_event("save_account", %{"account" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.company.id)
    params = if params["parent_id"] == "", do: Map.delete(params, "parent_id"), else: params

    case Finance.create_account(params) do
      {:ok, _} ->
        {:noreply,
         reload_company(socket) |> put_flash(:info, "Account added") |> assign(show_form: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add account")}
    end
  end

  def handle_event("delete_account", %{"id" => id}, socket) do
    account = Finance.get_account!(String.to_integer(id))

    case Finance.delete_account(account) do
      {:ok, _} ->
        {:noreply, reload_company(socket) |> put_flash(:info, "Account deleted")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Cannot delete account (may have children or journal lines)")}
    end
  end

  # --- Journal Entries ---
  def handle_event("save_journal_entry", %{"entry" => entry_params} = params, socket) do
    entry_params = Map.put(entry_params, "company_id", socket.assigns.company.id)
    lines_params = params["lines"] || %{}

    lines =
      lines_params
      |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
      |> Enum.map(fn {_k, v} -> v end)
      |> Enum.reject(fn l -> (l["account_id"] || "") == "" end)

    total_debit = lines |> Enum.map(&parse_float(&1["debit"])) |> Enum.sum()
    total_credit = lines |> Enum.map(&parse_float(&1["credit"])) |> Enum.sum()

    cond do
      length(lines) < 2 ->
        {:noreply, put_flash(socket, :error, "At least 2 lines required")}

      abs(total_debit - total_credit) > 0.01 ->
        {:noreply, put_flash(socket, :error, "Debits must equal credits")}

      true ->
        case Finance.create_journal_entry(entry_params) do
          {:ok, entry} ->
            Enum.each(lines, fn l ->
              Finance.create_journal_line(%{
                "entry_id" => entry.id,
                "account_id" => l["account_id"],
                "debit" => parse_float(l["debit"]),
                "credit" => parse_float(l["credit"]),
                "notes" => l["notes"]
              })
            end)

            {:noreply,
             reload_company(socket)
             |> put_flash(:info, "Journal entry created")
             |> assign(show_form: nil)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create journal entry")}
        end
    end
  end

  def handle_event("delete_journal_entry", %{"id" => id}, socket) do
    entry = Finance.get_journal_entry!(String.to_integer(id))
    Enum.each(entry.lines, &Finance.delete_journal_line/1)
    Finance.delete_journal_entry(entry)
    {:noreply, reload_company(socket) |> put_flash(:info, "Journal entry deleted")}
  end

  def handle_event("add_je_line", _, socket) do
    {:noreply, assign(socket, je_line_count: (socket.assigns[:je_line_count] || 2) + 1)}
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

  def handle_info(:do_qbo_sync, socket) do
    company_id = socket.assigns.company.id
    result = Quickbooks.sync_all(company_id)

    sync_result =
      case result do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> {:error, reason}
      end

    qbo_integration = Integrations.get_integration("quickbooks", company_id)

    {:noreply,
     assign(socket,
       qbo_syncing: false,
       qbo_sync_result: sync_result,
       qbo_integration: qbo_integration
     )}
  end

  def handle_info(_, socket), do: {:noreply, reload_company(socket)}

  defp reload_company(socket) do
    {company, sub_companies} = Corporate.get_company_consolidated!(socket.assigns.company.id)
    assign(socket,
      company: company,
      sub_companies: sub_companies,
      is_consolidated: sub_companies != [],
      page_title: company.name
    )
  end

  defp consolidated_with_company(company, sub_companies, field) do
    for c <- [company | sub_companies],
        item <- Map.get(c, field) || [] do
      {item, c.name}
    end
  end

  defp rows(assigns, field) do
    if assigns.is_consolidated,
      do: consolidated_with_company(assigns.company, assigns.sub_companies, field),
      else: Enum.map(Map.get(assigns.company, field) || [], &{&1, nil})
  end

  attr :is_consolidated, :boolean, required: true
  attr :name, :string, default: nil

  defp company_col(assigns) do
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

    <%= if @is_consolidated do %>
      <div class="panel" style="padding: 0.75rem 1rem; margin-bottom: 1rem; background: #f0f7f8; border-left: 3px solid #0d7680;">
        <span style="font-size: 0.85rem; color: #0d7680; font-weight: 600;">
          Consolidated view across {@company.name} and {length(@sub_companies)} subsidiaries
        </span>
      </div>
    <% end %>

    <div class="tabs">
      <button
        :for={
          tab <-
            ~w(overview holdings bank_accounts transactions documents governance compliance financials integrations comments)
        }
        class={"tab #{if @active_tab == tab, do: "tab-active"}"}
        phx-click="switch_tab"
        phx-value-tab={tab}
      >
        {tab_label(tab)}
      </button>
    </div>

    <div class="tab-body">
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
  defp tab_label("accounting"), do: "Accounting"
  defp tab_label("integrations"), do: "Integrations"
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
    assigns = assign(assigns, holdings_rows: rows(assigns, :asset_holdings))

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

  defp render_tab(%{active_tab: "bank_accounts"} = assigns) do
    assigns = assign(assigns, ba_rows: rows(assigns, :bank_accounts))

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

  defp render_tab(%{active_tab: "transactions"} = assigns) do
    assigns = assign(assigns, tx_rows: rows(assigns, :transactions))

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

  defp render_tab(%{active_tab: "documents"} = assigns) do
    assigns = assign(assigns, doc_rows: rows(assigns, :documents))

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

  defp render_tab(%{active_tab: "governance"} = assigns) do
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

  defp render_tab(%{active_tab: "compliance"} = assigns) do
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

  defp render_tab(%{active_tab: "financials"} = assigns) do
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

  defp render_tab(%{active_tab: "accounting"} = assigns) do
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
          {format_number(Enum.reduce(@je_list, 0.0, fn e, acc ->
            acc + Enum.reduce(e.lines || [], 0.0, &((&1.debit || 0.0) + &2))
          end))}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Credits</div>
        <div class="metric-value">
          {format_number(Enum.reduce(@je_list, 0.0, fn e, acc ->
            acc + Enum.reduce(e.lines || [], 0.0, &((&1.credit || 0.0) + &2))
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

  defp render_tab(%{active_tab: "integrations"} = assigns) do
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
    <div class="dialog-overlay" phx-click="close_form">
      <div class="dialog-panel" phx-click="noop">
        <div class="dialog-header">
          <h3>Add Holding</h3>
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

  defp render_inline_form(%{show_form: "bank_account"} = assigns) do
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

  defp render_inline_form(%{show_form: "transaction"} = assigns) do
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

  defp render_inline_form(%{show_form: "document"} = assigns) do
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

  defp render_inline_form(%{show_form: "board_meeting"} = assigns) do
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

  defp render_inline_form(%{show_form: "key_personnel"} = assigns) do
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

  defp render_inline_form(%{show_form: "beneficial_owner"} = assigns) do
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

  defp render_inline_form(%{show_form: "service_provider"} = assigns) do
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

  defp render_inline_form(%{show_form: "tax_deadline"} = assigns) do
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

  defp render_inline_form(%{show_form: "financial"} = assigns) do
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

  defp render_inline_form(%{show_form: "insurance_policy"} = assigns) do
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

  defp render_inline_form(%{show_form: "account"} = assigns) do
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

  defp render_inline_form(%{show_form: "journal_entry"} = assigns) do
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

  defp render_inline_form(%{show_form: "cap_table"} = assigns) do
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

  defp render_inline_form(%{show_form: "resolution"} = assigns) do
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

  defp render_inline_form(%{show_form: "deal"} = assigns) do
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

  defp render_inline_form(%{show_form: "jv"} = assigns) do
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

  defp render_inline_form(%{show_form: "poa"} = assigns) do
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

  defp render_inline_form(%{show_form: "equity_plan"} = assigns) do
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

  defp render_inline_form(%{show_form: "filing"} = assigns) do
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

  defp render_inline_form(%{show_form: "license"} = assigns) do
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

  defp render_inline_form(%{show_form: "esg"} = assigns) do
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

  defp render_inline_form(%{show_form: "sanctions"} = assigns) do
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

  defp render_inline_form(%{show_form: "fatca"} = assigns) do
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

  defp render_inline_form(%{show_form: "withholding"} = assigns) do
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

  defp render_inline_form(%{show_form: "liability"} = assigns) do
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

  defp render_inline_form(%{show_form: "dividend"} = assigns) do
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

  defp render_inline_form(assigns), do: ~H""

  defp parse_float(nil), do: 0.0
  defp parse_float(""), do: 0.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val / 1

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2)
  defp format_number(n) when is_integer(n), do: Integer.to_string(n) <> ".00"
  defp format_number(_), do: "0.00"

  defp format_qbo_sync_count({:ok, count}), do: "#{count} synced"
  defp format_qbo_sync_count({:error, reason}), do: "Error: #{inspect(reason)}"
  defp format_qbo_sync_count(_), do: "—"

  defp entry_totals(entry) do
    lines = entry.lines || []
    total_debit = Enum.reduce(lines, 0.0, &((&1.debit || 0.0) + &2))
    total_credit = Enum.reduce(lines, 0.0, &((&1.credit || 0.0) + &2))
    {total_debit, total_credit}
  end

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

  defp sanctions_status_tag("clear"), do: "tag-jade"
  defp sanctions_status_tag("flagged"), do: "tag-crimson"
  defp sanctions_status_tag("pending"), do: "tag-lemon"
  defp sanctions_status_tag(_), do: "tag-ink"

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
