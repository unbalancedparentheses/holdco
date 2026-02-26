defmodule HoldcoWeb.SearchLive do
  use HoldcoWeb, :live_view

  alias Holdco.Search

  @impl true
  def mount(%{"q" => query}, _session, socket) do
    results = Search.search(query)

    {:ok,
     assign(socket,
       page_title: "Search: #{query}",
       query: query,
       results: results
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Search",
       query: "",
       results: %{companies: [], holdings: [], transactions: [], documents: [], total: 0}
     )}
  end

  @impl true
  def handle_params(%{"q" => query}, _uri, socket) do
    results = Search.search(query)
    {:noreply, assign(socket, query: query, results: results, page_title: "Search: #{query}")}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/search?q=#{query}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Search</h1>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <form phx-submit="search" style="margin-bottom: 1.5rem;">
        <div style="display: flex; gap: 0.5rem;">
          <input
            type="text"
            name="q"
            value={@query}
            placeholder="Search companies, holdings, transactions, documents..."
            class="form-input"
            style="flex: 1;"
            autofocus
          />
          <button type="submit" class="btn btn-primary">Search</button>
        </div>
      </form>
    </div>

    <%= if @query != "" do %>
      <div class="section">
        <div class="section-head">
          <h2>{@results.total} results for "{@query}"</h2>
        </div>
      </div>

      <%= if @results.companies != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>Companies</h2>
          </div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Detail</th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.companies do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/companies/#{r.id}"}>{r.name}</.link></td>
                    <td>{r.detail}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.holdings != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>Holdings</h2>
          </div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Asset</th>
                  <th>Ticker</th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.holdings do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/holdings"}>{r.name}</.link></td>
                    <td class="td-mono">{r.detail}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.transactions != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>Transactions</h2>
          </div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Description</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.transactions do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/transactions"}>{r.name}</.link></td>
                    <td class="td-mono">{r.detail}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.documents != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>Documents</h2>
          </div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Type</th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @results.documents do %>
                  <tr>
                    <td class="td-name"><.link navigate={~p"/documents"}>{r.name}</.link></td>
                    <td><span class="tag tag-ink">{r.detail}</span></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if @results.total == 0 do %>
        <div class="section">
          <div class="panel">
            <div class="empty-state">No results found for "{@query}".</div>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end
end
