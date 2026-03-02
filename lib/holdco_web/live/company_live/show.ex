defmodule HoldcoWeb.CompanyLive.Show do
  use HoldcoWeb, :live_view

  import HoldcoWeb.CompanyLive.ShowHelpers, only: [parse_float: 1, tab_label: 1]
  import HoldcoWeb.CompanyLive.ShowTabs, only: [render_tab: 1]

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
  alias Holdco.Money

  @tabs ~w(overview holdings bank_accounts transactions documents governance compliance financials accounting integrations comments)
  @upload_dir Path.join([:code.priv_dir(:holdco), "static", "uploads"])

  @write_events ~w(
    save_holding delete_holding save_bank_account delete_bank_account
    save_transaction delete_transaction save_document delete_document
    save_board_meeting delete_board_meeting save_service_provider delete_service_provider
    save_key_personnel delete_key_personnel save_beneficial_owner delete_beneficial_owner
    save_tax_deadline delete_tax_deadline save_financial delete_financial
    save_insurance_policy delete_insurance_policy save_account delete_account
    save_journal_entry delete_journal_entry update_company
    save_cap_table delete_cap_table save_resolution delete_resolution
    save_deal delete_deal save_jv delete_jv save_poa delete_poa
    save_equity_plan delete_equity_plan save_filing delete_filing
    save_license delete_license save_esg delete_esg
    save_sanctions delete_sanctions save_fatca delete_fatca
    save_withholding delete_withholding save_liability delete_liability
    save_dividend delete_dividend qbo_disconnect qbo_sync
  )

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

  # --- Generic Events ---

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

  # --- Permission Guard (covers all write events) ---

  def handle_event(event, _params, %{assigns: %{can_write: false}} = socket)
      when event in @write_events do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

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

      Money.to_float(Money.abs(Money.sub(total_debit, total_credit))) > 0.01 ->
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

  # --- handle_info ---

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

  # --- Render ---

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

  # --- Private helpers ---

  defp reload_company(socket) do
    {company, sub_companies} = Corporate.get_company_consolidated!(socket.assigns.company.id)
    assign(socket,
      company: company,
      sub_companies: sub_companies,
      is_consolidated: sub_companies != [],
      page_title: company.name
    )
  end

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
end
