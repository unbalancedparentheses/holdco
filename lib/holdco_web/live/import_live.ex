NimbleCSV.define(Holdco.CSVParser, separator: ",", escape: "\"")

defmodule HoldcoWeb.ImportLive do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Assets, Banking}
  alias Holdco.CSVParser
  alias Holdco.Import.XlsxParser

  @impl true
  def mount(params, _session, socket) do
    initial_tab =
      case params["type"] do
        "holdings" -> "holdings"
        "transactions" -> "transactions"
        _ -> "companies"
      end

    {:ok,
     socket
     |> assign(
       page_title: "Import CSV/Excel",
       active_tab: initial_tab,
       results: nil,
       import_history: []
     )
     |> allow_upload(:csv_file,
       accept: ~w(.csv .xlsx .xls),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab =
      case params["type"] do
        "holdings" -> "holdings"
        "transactions" -> "transactions"
        _ -> socket.assigns.active_tab
      end

    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event(_event, _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to import data")}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(active_tab: tab, results: nil)
     |> allow_upload(:csv_file,
       accept: ~w(.csv .xlsx .xls),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("import", _params, socket) do
    case uploaded_entries(socket, :csv_file) do
      {[], _} ->
        {:noreply, put_flash(socket, :error, "Please select a file")}

      {[entry], _} ->
        results =
          consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
            case detect_file_type(entry.client_name) do
              :xlsx ->
                {:ok, process_xlsx(path, socket.assigns.active_tab)}

              :csv ->
                csv_content = File.read!(path)
                {:ok, process_csv(csv_content, socket.assigns.active_tab)}
            end
          end)

        result = List.first(results)

        history_entry = %{
          type: socket.assigns.active_tab,
          filename: entry.client_name,
          created: result.created,
          errors: length(result.errors),
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }

        {:noreply,
         assign(socket,
           results: result,
           import_history: [history_entry | socket.assigns.import_history]
         )}
    end
  end

  defp detect_file_type(filename) do
    case Path.extname(String.downcase(filename)) do
      ext when ext in [".xlsx", ".xls"] -> :xlsx
      _ -> :csv
    end
  end

  defp process_xlsx(path, type) do
    case XlsxParser.parse_file(path, skip_headers: true) do
      {:ok, rows} ->
        do_import(rows, type)

      {:error, reason} ->
        %{created: 0, errors: [{"Excel Parse Error", to_string(reason)}]}
    end
  end

  defp process_csv(content, type) do
    try do
      rows = CSVParser.parse_string(content, skip_headers: true)
      do_import(rows, type)
    rescue
      e ->
        %{created: 0, errors: [{"CSV Parse Error", Exception.message(e)}]}
    end
  end

  defp do_import(rows, "companies") do
    companies_by_name = build_company_lookup()

    results =
      Enum.with_index(rows, 2)
      |> Enum.map(fn {row, line} ->
        case row do
          [name, country, entity_type, category, ownership_pct | _rest] ->
            attrs = %{
              "name" => String.trim(name),
              "country" => String.trim(country),
              "category" => pick_category(entity_type, category),
              "ownership_pct" => parse_ownership(ownership_pct)
            }

            if Map.has_key?(companies_by_name, String.downcase(String.trim(name))) do
              {:error, {line, "Company '#{String.trim(name)}' already exists"}}
            else
              case Corporate.create_company(attrs) do
                {:ok, _company} -> :ok
                {:error, changeset} -> {:error, {line, changeset_errors(changeset)}}
              end
            end

          _ ->
            {:error, {line, "Invalid number of columns"}}
        end
      end)

    tally_results(results)
  end

  defp do_import(rows, "holdings") do
    companies_by_name = build_company_lookup()

    results =
      Enum.with_index(rows, 2)
      |> Enum.map(fn {row, line} ->
        case row do
          [asset, ticker, asset_type, quantity, currency, company_name | _rest] ->
            company_name = String.trim(company_name)

            case Map.get(companies_by_name, String.downcase(company_name)) do
              nil when company_name != "" ->
                {:error, {line, "Company '#{company_name}' not found"}}

              company_id ->
                attrs = %{
                  "asset" => String.trim(asset),
                  "ticker" => String.trim(ticker),
                  "asset_type" => normalize_asset_type(String.trim(asset_type)),
                  "quantity" => parse_float(quantity),
                  "currency" => String.trim(currency),
                  "company_id" => company_id
                }

                case Assets.create_holding(attrs) do
                  {:ok, _holding} -> :ok
                  {:error, changeset} -> {:error, {line, changeset_errors(changeset)}}
                end
            end

          _ ->
            {:error, {line, "Invalid number of columns"}}
        end
      end)

    tally_results(results)
  end

  defp do_import(rows, "transactions") do
    companies_by_name = build_company_lookup()

    results =
      Enum.with_index(rows, 2)
      |> Enum.map(fn {row, line} ->
        case row do
          [date, description, amount, currency, category, company_name | _rest] ->
            company_name = String.trim(company_name)

            case Map.get(companies_by_name, String.downcase(company_name)) do
              nil when company_name != "" ->
                {:error, {line, "Company '#{company_name}' not found"}}

              company_id ->
                attrs = %{
                  "date" => String.trim(date),
                  "description" => String.trim(description),
                  "amount" => parse_float(amount),
                  "currency" => String.trim(currency),
                  "transaction_type" => String.trim(category),
                  "company_id" => company_id
                }

                case Banking.create_transaction(attrs) do
                  {:ok, _transaction} -> :ok
                  {:error, changeset} -> {:error, {line, changeset_errors(changeset)}}
                end
            end

          _ ->
            {:error, {line, "Invalid number of columns"}}
        end
      end)

    tally_results(results)
  end

  defp do_import(_rows, _type), do: %{created: 0, errors: [{"Error", "Unknown import type"}]}

  defp build_company_lookup do
    Corporate.list_companies()
    |> Enum.reduce(%{}, fn c, acc ->
      Map.put(acc, String.downcase(c.name), c.id)
    end)
  end

  defp pick_category(entity_type, category) do
    et = String.trim(entity_type)
    cat = String.trim(category)
    if cat != "", do: cat, else: et
  end

  defp parse_ownership(val) do
    trimmed = String.trim(val)

    case Float.parse(trimmed) do
      {n, _} -> round(n)
      :error -> nil
    end
  end

  defp parse_float(val) do
    trimmed = String.trim(val)

    case Float.parse(trimmed) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp normalize_asset_type(type) do
    type
    |> String.downcase()
    |> String.replace(" ", "_")
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end

  defp tally_results(results) do
    {oks, errs} = Enum.split_with(results, &(&1 == :ok))

    errors =
      Enum.map(errs, fn {:error, {line, msg}} -> {"Row #{line}", msg} end)

    %{created: length(oks), errors: errors}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Import CSV/Excel</h1>
          <p class="deck">Upload a CSV or Excel file to bulk-import records</p>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div style="display: flex; gap: 0.5rem; margin-bottom: 1.5rem;">
        <button
          phx-click="switch_tab"
          phx-value-tab="companies"
          class={"btn #{if @active_tab == "companies", do: "btn-primary", else: "btn-secondary"}"}
        >
          Companies
        </button>
        <button
          phx-click="switch_tab"
          phx-value-tab="holdings"
          class={"btn #{if @active_tab == "holdings", do: "btn-primary", else: "btn-secondary"}"}
        >
          Positions
        </button>
        <button
          phx-click="switch_tab"
          phx-value-tab="transactions"
          class={"btn #{if @active_tab == "transactions", do: "btn-primary", else: "btn-secondary"}"}
        >
          Transactions
        </button>
      </div>

      <div class="panel" style="padding: 1.5rem;">
        <h3 style="margin-bottom: 1rem;">
          Import {String.capitalize(@active_tab)}
        </h3>

        <div style="margin-bottom: 1rem; padding: 1rem; background: var(--bg-wash, #f5f5f5); border-radius: 4px;">
          <strong>Expected columns (CSV or Excel):</strong>
          <br />
          <%= case @active_tab do %>
            <% "companies" -> %>
              <code>Name, Country, Entity Type, Category, Ownership %</code>
              <br />
              <small style="color: var(--text-muted, #666);">
                Example: Acme Corp, US, LLC, Operating, 100
              </small>
            <% "holdings" -> %>
              <code>Asset, Ticker, Type, Quantity, Currency, Company Name</code>
              <br />
              <small style="color: var(--text-muted, #666);">
                Example: Apple Inc, AAPL, stock, 100, USD, Acme Corp
              </small>
            <% "transactions" -> %>
              <code>Date, Description, Amount, Currency, Category, Company Name</code>
              <br />
              <small style="color: var(--text-muted, #666);">
                Example: 2025-01-15, Office rent, -5000, USD, expense, Acme Corp
              </small>
          <% end %>
        </div>

        <form id="import-form" phx-submit="import" phx-change="validate">
          <div class="form-group">
            <label class="form-label">CSV or Excel File</label>
            <.live_file_input upload={@uploads.csv_file} />
            <%= for entry <- @uploads.csv_file.entries do %>
              <div style="margin-top: 0.5rem; color: var(--text-muted, #666);">
                {entry.client_name} ({format_bytes(entry.client_size)})
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  style="margin-left: 0.5rem; color: var(--text-error, red); cursor: pointer; border: none; background: none;"
                >
                  &times;
                </button>
              </div>
              <%= for err <- upload_errors(@uploads.csv_file, entry) do %>
                <p style="color: var(--text-error, red); margin-top: 0.25rem;">
                  {upload_error_message(err)}
                </p>
              <% end %>
            <% end %>
          </div>

          <div class="form-actions" style="margin-top: 1rem;">
            <%= if @can_write do %>
              <button type="submit" class="btn btn-primary">
                Import {String.capitalize(@active_tab)}
              </button>
            <% else %>
              <button type="button" class="btn btn-primary" disabled>
                Import (no permission)
              </button>
            <% end %>
          </div>
        </form>

        <%= if @results do %>
          <div style="margin-top: 1.5rem; padding: 1rem; border: 1px solid var(--border, #ddd); border-radius: 4px;">
            <h4>Import Results</h4>
            <div style="margin-top: 0.5rem;">
              <span class="tag tag-jade">{@results.created} created</span>
              <%= if length(@results.errors) > 0 do %>
                <span class="tag tag-crimson" style="margin-left: 0.5rem;">
                  {length(@results.errors)} errors
                </span>
              <% end %>
            </div>

            <%= if length(@results.errors) > 0 do %>
              <div style="margin-top: 1rem;">
                <table>
                  <thead>
                    <tr>
                      <th>Row</th>
                      <th>Error</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {row_label, error_msg} <- @results.errors do %>
                      <tr>
                        <td><strong>{row_label}</strong></td>
                        <td style="color: var(--text-error, red);">{error_msg}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @import_history != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Recent Imports (This Session)</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Time</th>
                <th>Type</th>
                <th>File</th>
                <th class="th-num">Created</th>
                <th class="th-num">Errors</th>
              </tr>
            </thead>
            <tbody>
              <%= for h <- @import_history do %>
                <tr>
                  <td class="td-mono">{NaiveDateTime.to_string(h.timestamp)}</td>
                  <td><span class="tag tag-ink">{String.capitalize(h.type)}</span></td>
                  <td class="td-name">{h.filename}</td>
                  <td class="td-num num-positive">{h.created}</td>
                  <td class={"td-num #{if h.errors > 0, do: "num-negative", else: ""}"}>{h.errors}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp upload_error_message(:too_large), do: "File is too large (max 10 MB)"
  defp upload_error_message(:not_accepted), do: "Only .csv and .xlsx files are accepted"
  defp upload_error_message(:too_many_files), do: "Only one file at a time"
  defp upload_error_message(err), do: "Upload error: #{inspect(err)}"
end
