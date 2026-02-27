defmodule HoldcoWeb.ContactLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Collaboration, Corporate}
  alias Holdco.Collaboration.Contact

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Holdco.PubSub, "contacts")

    contacts = Collaboration.list_contacts()
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Contacts",
       contacts: contacts,
       filtered_contacts: contacts,
       companies: companies,
       search: "",
       show_form: nil,
       editing_item: nil,
       selected_contact: nil,
       interactions: nil,
       show_interactions: false,
       show_interaction_form: false
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: "contact", editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: nil, editing_item: nil)}

  def handle_event("search", %{"q" => q}, socket) do
    filtered =
      if q == "" do
        socket.assigns.contacts
      else
        term = String.downcase(q)

        Enum.filter(socket.assigns.contacts, fn c ->
          String.contains?(String.downcase(c.name || ""), term) or
            String.contains?(String.downcase(c.organization || ""), term) or
            String.contains?(String.downcase(c.email || ""), term) or
            String.contains?(String.downcase(c.role_tag || ""), term)
        end)
      end

    {:noreply, assign(socket, search: q, filtered_contacts: filtered)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    contact = Collaboration.get_contact!(String.to_integer(id))
    {:noreply, assign(socket, show_form: "contact", editing_item: contact)}
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

  def handle_event("save", %{"contact" => params}, socket) do
    case Collaboration.create_contact(params) do
      {:ok, _contact} ->
        contacts = Collaboration.list_contacts()

        {:noreply,
         socket
         |> assign(
           contacts: contacts,
           filtered_contacts: filter_contacts(contacts, socket.assigns.search),
           show_form: nil,
           editing_item: nil
         )
         |> put_flash(:info, "Contact created")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create contact")}
    end
  end

  def handle_event("update", %{"contact" => params}, socket) do
    contact = socket.assigns.editing_item

    case Collaboration.update_contact(contact, params) do
      {:ok, _contact} ->
        contacts = Collaboration.list_contacts()

        {:noreply,
         socket
         |> assign(
           contacts: contacts,
           filtered_contacts: filter_contacts(contacts, socket.assigns.search),
           show_form: nil,
           editing_item: nil
         )
         |> put_flash(:info, "Contact updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update contact")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    contact = Collaboration.get_contact!(String.to_integer(id))
    Collaboration.delete_contact(contact)
    contacts = Collaboration.list_contacts()

    {:noreply,
     socket
     |> assign(
       contacts: contacts,
       filtered_contacts: filter_contacts(contacts, socket.assigns.search)
     )
     |> put_flash(:info, "Contact deleted")}
  end

  def handle_event("view_interactions", %{"id" => id}, socket) do
    contact = Collaboration.get_contact!(String.to_integer(id))
    interactions = Collaboration.list_interactions(contact.id)

    {:noreply,
     assign(socket,
       selected_contact: contact,
       interactions: interactions,
       show_interactions: true,
       show_interaction_form: false
     )}
  end

  def handle_event("close_interactions", _, socket) do
    {:noreply,
     assign(socket,
       selected_contact: nil,
       interactions: nil,
       show_interactions: false,
       show_interaction_form: false
     )}
  end

  def handle_event("add_interaction", _, socket) do
    {:noreply, assign(socket, show_interaction_form: true)}
  end

  def handle_event("cancel_interaction_form", _, socket) do
    {:noreply, assign(socket, show_interaction_form: false)}
  end

  def handle_event("save_interaction", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_interaction", %{"interaction" => params}, socket) do
    contact = socket.assigns.selected_contact

    attrs = Map.put(params, "contact_id", contact.id)

    case Collaboration.create_interaction(attrs) do
      {:ok, _interaction} ->
        interactions = Collaboration.list_interactions(contact.id)

        {:noreply,
         socket
         |> assign(interactions: interactions, show_interaction_form: false)
         |> put_flash(:info, "Interaction added")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add interaction")}
    end
  end

  def handle_event("delete_interaction", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_interaction", %{"id" => id}, socket) do
    interaction = Collaboration.get_interaction!(String.to_integer(id))
    Collaboration.delete_interaction(interaction)
    interactions = Collaboration.list_interactions(socket.assigns.selected_contact.id)

    {:noreply,
     socket
     |> assign(interactions: interactions)
     |> put_flash(:info, "Interaction deleted")}
  end

  @impl true
  def handle_info(_, socket) do
    contacts = Collaboration.list_contacts()

    {:noreply,
     assign(socket,
       contacts: contacts,
       filtered_contacts: filter_contacts(contacts, socket.assigns.search)
     )}
  end

  defp filter_contacts(contacts, ""), do: contacts
  defp filter_contacts(contacts, nil), do: contacts

  defp filter_contacts(contacts, q) do
    term = String.downcase(q)

    Enum.filter(contacts, fn c ->
      String.contains?(String.downcase(c.name || ""), term) or
        String.contains?(String.downcase(c.organization || ""), term) or
        String.contains?(String.downcase(c.email || ""), term) or
        String.contains?(String.downcase(c.role_tag || ""), term)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Contacts</h1>
          <p class="deck">Key people across the holding structure</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Contact</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="search" style="display: flex; align-items: center; gap: 0.5rem;">
        <input
          type="text"
          name="q"
          value={@search}
          placeholder="Search contacts..."
          class="form-input"
          style="max-width: 320px;"
          phx-debounce="300"
        />
      </form>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Contacts</div>
        <div class="metric-value">{length(@contacts)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Organizations</div>
        <div class="metric-value">
          {@contacts |> Enum.map(& &1.organization) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length()}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Role Tags</div>
        <div class="metric-value">
          {@contacts |> Enum.map(& &1.role_tag) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length()}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Contacts</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Title</th>
              <th>Organization</th>
              <th>Email</th>
              <th>Phone</th>
              <th>Role</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for contact <- @filtered_contacts do %>
              <tr>
                <td class="td-name">{contact.name}</td>
                <td>{contact.title || "---"}</td>
                <td>{contact.organization || "---"}</td>
                <td class="td-mono">{contact.email || "---"}</td>
                <td class="td-mono">{contact.phone || "---"}</td>
                <td>
                  <%= if contact.role_tag do %>
                    <span class={"tag #{role_tag_class(contact.role_tag)}"}>{contact.role_tag}</span>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button
                      phx-click="view_interactions"
                      phx-value-id={contact.id}
                      class="btn btn-secondary btn-sm"
                    >
                      History
                    </button>
                    <%= if @can_write do %>
                      <button
                        phx-click="edit"
                        phx-value-id={contact.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={contact.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this contact?"
                      >
                        Del
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @filtered_contacts == [] do %>
          <div class="empty-state">
            <p>No contacts found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Add lawyers, accountants, bankers, and other key people across your holding structure.
            </p>
            <%= if @can_write and @search == "" do %>
              <div style="margin-top: 0.75rem;">
                <button class="btn btn-primary btn-sm" phx-click="show_form">
                  Add your first contact
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @editing_item, do: "Edit Contact", else: "Add Contact"}</h3>
          </div>
          <div class="dialog-body">
            <.form
              for={
                if @editing_item,
                  do: to_form(Contact.changeset(@editing_item, %{})),
                  else: to_form(Contact.changeset(%Contact{}, %{}))
              }
              phx-submit={if @editing_item, do: "update", else: "save"}
            >
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="contact[name]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Title</label>
                <input
                  type="text"
                  name="contact[title]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.title, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Organization</label>
                <input
                  type="text"
                  name="contact[organization]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.organization, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Email</label>
                <input
                  type="email"
                  name="contact[email]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.email, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Phone</label>
                <input
                  type="text"
                  name="contact[phone]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.phone, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Role</label>
                <select name="contact[role_tag]" class="form-select">
                  <option value="">Select role...</option>
                  <%= for role <- ~w(lawyer accountant banker regulator investor advisor board_member other) do %>
                    <option
                      value={role}
                      selected={@editing_item && @editing_item.role_tag == role}
                    >
                      {role |> String.replace("_", " ") |> String.capitalize()}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea
                  name="contact[notes]"
                  class="form-input"
                  rows="3"
                >{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @editing_item, do: "Update Contact", else: "Add Contact"}
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_interactions && @selected_contact do %>
      <div class="dialog-overlay" phx-click="close_interactions">
        <div class="dialog-panel" phx-click="noop" style="max-width: 640px;">
          <div class="dialog-header">
            <h3>Interaction History &mdash; {@selected_contact.name}</h3>
          </div>
          <div class="dialog-body">
            <%= if @can_write do %>
              <div style="margin-bottom: 1rem;">
                <button class="btn btn-primary btn-sm" phx-click="add_interaction">
                  Add Interaction
                </button>
              </div>
            <% end %>

            <%= if @show_interaction_form do %>
              <div class="panel" style="margin-bottom: 1rem; padding: 1rem;">
                <.form for={%{}} phx-submit="save_interaction">
                  <div class="form-group">
                    <label class="form-label">Type *</label>
                    <select name="interaction[interaction_type]" class="form-select" required>
                      <option value="">Select type...</option>
                      <option value="call">Call</option>
                      <option value="meeting">Meeting</option>
                      <option value="email">Email</option>
                      <option value="note">Note</option>
                    </select>
                  </div>
                  <div class="form-group">
                    <label class="form-label">Date</label>
                    <input type="date" name="interaction[date]" class="form-input" />
                  </div>
                  <div class="form-group">
                    <label class="form-label">Summary *</label>
                    <input
                      type="text"
                      name="interaction[summary]"
                      class="form-input"
                      required
                      placeholder="Brief description of the interaction"
                    />
                  </div>
                  <div class="form-group">
                    <label class="form-label">Notes</label>
                    <textarea
                      name="interaction[notes]"
                      class="form-input"
                      rows="3"
                      placeholder="Additional details..."
                    ></textarea>
                  </div>
                  <div class="form-actions">
                    <button type="submit" class="btn btn-primary">Save Interaction</button>
                    <button
                      type="button"
                      phx-click="cancel_interaction_form"
                      class="btn btn-secondary"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              </div>
            <% end %>

            <%= if @interactions == [] do %>
              <div class="empty-state">
                <p>No interactions recorded yet.</p>
                <p style="color: var(--muted); font-size: 0.9rem;">
                  Track calls, meetings, emails, and notes for this contact.
                </p>
              </div>
            <% else %>
              <table>
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Date</th>
                    <th>Summary</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <%= for interaction <- @interactions do %>
                    <tr>
                      <td>
                        <span class={"tag #{interaction_type_class(interaction.interaction_type)}"}>
                          {interaction.interaction_type}
                        </span>
                      </td>
                      <td class="td-mono">{interaction.date || "---"}</td>
                      <td>
                        <div>{interaction.summary}</div>
                        <%= if interaction.notes do %>
                          <div style="color: var(--muted); font-size: 0.85rem; margin-top: 0.25rem;">
                            {interaction.notes}
                          </div>
                        <% end %>
                      </td>
                      <td>
                        <%= if @can_write do %>
                          <button
                            phx-click="delete_interaction"
                            phx-value-id={interaction.id}
                            class="btn btn-danger btn-sm"
                            data-confirm="Delete this interaction?"
                          >
                            Del
                          </button>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp interaction_type_class("call"), do: "tag-jade"
  defp interaction_type_class("meeting"), do: "tag-teal"
  defp interaction_type_class("email"), do: "tag-lemon"
  defp interaction_type_class("note"), do: "tag-ink"
  defp interaction_type_class(_), do: "tag-ink"

  defp role_tag_class("lawyer"), do: "tag-ink"
  defp role_tag_class("accountant"), do: "tag-jade"
  defp role_tag_class("banker"), do: "tag-teal"
  defp role_tag_class("regulator"), do: "tag-crimson"
  defp role_tag_class("investor"), do: "tag-lemon"
  defp role_tag_class("advisor"), do: "tag-ink"
  defp role_tag_class("board_member"), do: "tag-teal"
  defp role_tag_class(_), do: "tag-ink"
end
