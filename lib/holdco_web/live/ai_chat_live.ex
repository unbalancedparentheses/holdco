defmodule HoldcoWeb.AiChatLive do
  use HoldcoWeb, :live_view

  alias Holdco.AI

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    conversations = AI.list_conversations(user_id)

    {:ok,
     assign(socket,
       page_title: "AI Chat",
       conversations: conversations,
       current_conversation: nil,
       messages: [],
       input: "",
       loading: false,
       configured: AI.configured?()
     )}
  end

  @impl true
  def handle_event("new_conversation", _params, socket) do
    user_id = socket.assigns.current_scope.user.id

    case AI.create_conversation(%{user_id: user_id, title: "New conversation"}) do
      {:ok, conv} ->
        conversations = AI.list_conversations(user_id)

        {:noreply,
         assign(socket,
           conversations: conversations,
           current_conversation: conv,
           messages: [],
           input: ""
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create conversation")}
    end
  end

  def handle_event("select_conversation", %{"id" => id}, socket) do
    conv = AI.get_conversation!(String.to_integer(id))

    {:noreply,
     assign(socket,
       current_conversation: conv,
       messages: conv.messages,
       input: ""
     )}
  end

  def handle_event("delete_conversation", %{"id" => id}, socket) do
    AI.delete_conversation(String.to_integer(id))
    user_id = socket.assigns.current_scope.user.id
    conversations = AI.list_conversations(user_id)

    current =
      if socket.assigns.current_conversation &&
           socket.assigns.current_conversation.id == String.to_integer(id) do
        nil
      else
        socket.assigns.current_conversation
      end

    {:noreply,
     assign(socket,
       conversations: conversations,
       current_conversation: current,
       messages: if(current, do: socket.assigns.messages, else: [])
     )}
  end

  def handle_event("update_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, input: value)}
  end

  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    content = String.trim(content)

    if content == "" or socket.assigns.loading or socket.assigns.current_conversation == nil do
      {:noreply, socket}
    else
      conv = socket.assigns.current_conversation

      # Save user message
      {:ok, user_msg} = AI.add_message(conv.id, "user", content)

      # Auto-title on first message
      if length(socket.assigns.messages) == 0 do
        title = String.slice(content, 0, 60)
        AI.update_conversation_title(conv, title)
      end

      messages = socket.assigns.messages ++ [user_msg]

      # Trigger async LLM call
      send(self(), :call_llm)

      {:noreply, assign(socket, messages: messages, input: "", loading: true)}
    end
  end

  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:call_llm, socket) do
    conv = socket.assigns.current_conversation
    api_messages = AI.format_messages_for_api(socket.assigns.messages)

    case AI.chat(api_messages) do
      {:ok, response} ->
        {:ok, assistant_msg} = AI.add_message(conv.id, "assistant", response)
        messages = socket.assigns.messages ++ [assistant_msg]
        user_id = socket.assigns.current_scope.user.id

        {:noreply,
         assign(socket,
           messages: messages,
           loading: false,
           conversations: AI.list_conversations(user_id)
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "AI error: #{reason}")
         |> assign(loading: false)}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>AI Chat</h1>
      <p class="deck">Ask questions about your portfolio, companies, and financial data</p>
      <hr class="page-title-rule" />
    </div>

    <%= unless @configured do %>
      <div style="padding: 2rem; text-align: center; background: #fff3e0; border-radius: 6px; margin-bottom: 1.5rem;">
        <p style="margin-bottom: 0.5rem;">AI is not configured yet.</p>
        <.link navigate={~p"/settings"} class="btn btn-primary">Go to Settings → AI</.link>
      </div>
    <% end %>

    <div style="display: flex; gap: 1rem; height: calc(100vh - 280px); min-height: 400px;">
      <%!-- Sidebar --%>
      <div style="width: 260px; flex-shrink: 0; display: flex; flex-direction: column; border-right: 1px solid #e0e0e0; padding-right: 1rem;">
        <button
          class="btn btn-primary btn-sm"
          phx-click="new_conversation"
          style="margin-bottom: 0.75rem; width: 100%;"
          disabled={not @configured}
        >
          + New Chat
        </button>
        <div style="overflow-y: auto; flex: 1;">
          <%= for conv <- @conversations do %>
            <div
              style={"display: flex; align-items: center; padding: 0.5rem; border-radius: 4px; cursor: pointer; margin-bottom: 2px; #{if @current_conversation && @current_conversation.id == conv.id, do: "background: #e3f2fd;", else: ""}"}
              phx-click="select_conversation"
              phx-value-id={conv.id}
            >
              <span style="flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 0.85rem;">
                {conv.title || "Untitled"}
              </span>
              <button
                phx-click="delete_conversation"
                phx-value-id={conv.id}
                class="btn btn-danger btn-sm"
                style="padding: 0.1rem 0.3rem; font-size: 0.7rem; flex-shrink: 0; margin-left: 0.25rem;"
                data-confirm="Delete this conversation?"
              >
                &times;
              </button>
            </div>
          <% end %>
          <%= if @conversations == [] do %>
            <div style="text-align: center; color: #999; font-size: 0.85rem; padding: 1rem 0;">
              No conversations yet
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Chat area --%>
      <div style="flex: 1; display: flex; flex-direction: column; min-width: 0;">
        <%= if @current_conversation do %>
          <%!-- Messages --%>
          <div
            id="chat-messages"
            phx-hook="ScrollBottom"
            style="flex: 1; overflow-y: auto; padding: 1rem; display: flex; flex-direction: column; gap: 0.75rem;"
          >
            <%= for msg <- @messages do %>
              <div style={"display: flex; #{if msg.role == "user", do: "justify-content: flex-end;", else: "justify-content: flex-start;"}"}>
                <div style={"max-width: 75%; padding: 0.75rem 1rem; border-radius: 12px; #{if msg.role == "user", do: "background: #e3f2fd; border-bottom-right-radius: 4px;", else: "background: #f5f5f5; border-bottom-left-radius: 4px;"}"}>
                  <div style="font-size: 0.7rem; color: #999; margin-bottom: 0.25rem;">
                    {if msg.role == "user", do: "You", else: "AI Assistant"}
                  </div>
                  <div style="white-space: pre-wrap; word-break: break-word; font-size: 0.9rem;">
                    {msg.content}
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @loading do %>
              <div style="display: flex; justify-content: flex-start;">
                <div style="padding: 0.75rem 1rem; border-radius: 12px; background: #f5f5f5; border-bottom-left-radius: 4px;">
                  <div style="font-size: 0.7rem; color: #999; margin-bottom: 0.25rem;">AI Assistant</div>
                  <div style="color: #666;">Thinking...</div>
                </div>
              </div>
            <% end %>

            <%= if @messages == [] and not @loading do %>
              <div style="flex: 1; display: flex; align-items: center; justify-content: center; color: #999;">
                Ask a question about your portfolio data
              </div>
            <% end %>
          </div>

          <%!-- Input bar --%>
          <div style="border-top: 1px solid #e0e0e0; padding: 0.75rem;">
            <form phx-submit="send_message" style="display: flex; gap: 0.5rem;">
              <input
                type="text"
                name="message[content]"
                value={@input}
                phx-keyup="update_input"
                class="form-input"
                style="flex: 1;"
                placeholder="Ask about your portfolio..."
                autocomplete="off"
                disabled={@loading}
              />
              <button
                type="submit"
                class="btn btn-primary"
                disabled={@loading or @input == ""}
              >
                Send
              </button>
            </form>
          </div>
        <% else %>
          <div style="flex: 1; display: flex; align-items: center; justify-content: center; color: #999; font-size: 1.1rem;">
            Select a conversation or start a new one
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
