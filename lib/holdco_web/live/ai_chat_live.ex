defmodule HoldcoWeb.AiChatLive do
  use HoldcoWeb, :live_view

  alias Holdco.AI

  alias Holdco.Accounts

  @impl true
  def mount(_params, session, socket) do
    user =
      cond do
        socket.assigns[:current_scope] && socket.assigns.current_scope.user ->
          socket.assigns.current_scope.user

        session["user_token"] ->
          case Accounts.get_user_by_session_token(session["user_token"]) do
            {user, _} -> user
            _ -> nil
          end

        true ->
          nil
      end

    if user do
      conversations = AI.list_conversations(user.id)

      {:ok,
       assign(socket,
         user_id: user.id,
         conversations: conversations,
         current_conversation: nil,
         messages: [],
         input: "",
         loading: false,
         configured: AI.configured?(),
         chat_open: false,
         show_history: false
       ), layout: false}
    else
      {:ok,
       assign(socket,
         user_id: nil,
         conversations: [],
         current_conversation: nil,
         messages: [],
         input: "",
         loading: false,
         configured: false,
         chat_open: false,
         show_history: false
       ), layout: false}
    end
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    opening = !socket.assigns.chat_open

    socket =
      if opening && socket.assigns.current_conversation == nil && socket.assigns.configured do
        ensure_conversation(socket)
      else
        socket
      end

    {:noreply, assign(socket, chat_open: opening, show_history: false)}
  end

  def handle_event("toggle_history", _params, socket) do
    {:noreply, assign(socket, show_history: !socket.assigns.show_history)}
  end

  def handle_event("new_conversation", _params, %{assigns: %{user_id: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("new_conversation", _params, socket) do
    user_id = socket.assigns.user_id

    case AI.create_conversation(%{user_id: user_id, title: "New conversation"}) do
      {:ok, conv} ->
        conversations = AI.list_conversations(user_id)

        {:noreply,
         assign(socket,
           conversations: conversations,
           current_conversation: conv,
           messages: [],
           input: "",
           show_history: false
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
       input: "",
       show_history: false
     )}
  end

  def handle_event("delete_conversation", %{"id" => id}, socket) do
    AI.delete_conversation(String.to_integer(id))
    user_id = socket.assigns.user_id
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

      {:ok, user_msg} = AI.add_message(conv.id, "user", content)

      if length(socket.assigns.messages) == 0 do
        title = String.slice(content, 0, 60)
        AI.update_conversation_title(conv, title)
      end

      messages = socket.assigns.messages ++ [user_msg]

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
        user_id = socket.assigns.user_id

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

  defp ensure_conversation(socket) do
    case socket.assigns.conversations do
      [latest | _] ->
        conv = AI.get_conversation!(latest.id)
        assign(socket, current_conversation: conv, messages: conv.messages)

      [] ->
        case AI.create_conversation(%{
               user_id: socket.assigns.user_id,
               title: "New conversation"
             }) do
          {:ok, conv} ->
            assign(socket,
              conversations: AI.list_conversations(socket.assigns.user_id),
              current_conversation: conv,
              messages: []
            )

          _ ->
            socket
        end
    end
  end

  @impl true
  def render(%{user_id: nil} = assigns) do
    ~H"""
    <div id="ai-chat-drawer-inner"></div>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="ai-chat-drawer-inner">
      <%!-- FAB — hidden when drawer is open --%>
      <%= unless @chat_open do %>
        <button class="ai-chat-fab" phx-click="toggle_chat" aria-label="Open AI Chat">
          <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>
        </button>
      <% end %>

      <%!-- Drawer --%>
      <div class={"ai-chat-panel #{if @chat_open, do: "ai-chat-panel-open"}"}>
        <%!-- Header --%>
        <div class="ai-chat-header">
          <div class="ai-chat-header-left">
            <span class="ai-chat-title">AI Chat</span>
            <%= if @current_conversation && @current_conversation.title != "New conversation" do %>
              <span class="ai-chat-conv-title">{@current_conversation.title}</span>
            <% end %>
          </div>
          <div class="ai-chat-header-actions">
            <button
              phx-click="toggle_history"
              class="ai-chat-icon-btn"
              title="Conversation history"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
            </button>
            <button
              phx-click="new_conversation"
              class="ai-chat-icon-btn"
              title="New conversation"
              disabled={not @configured}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
            </button>
            <button
              phx-click="toggle_chat"
              class="ai-chat-icon-btn"
              title="Close"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
            </button>
          </div>
        </div>

        <%!-- Config warning --%>
        <%= unless @configured do %>
          <div class="ai-chat-notice">
            AI provider not configured.
            <.link navigate={~p"/settings"} class="ai-chat-notice-link">Configure in Settings</.link>
          </div>
        <% end %>

        <%!-- Conversation history dropdown --%>
        <%= if @show_history do %>
          <div class="ai-chat-history">
            <%= for conv <- @conversations do %>
              <div class={"ai-chat-history-item #{if @current_conversation && @current_conversation.id == conv.id, do: "active"}"}>
                <span
                  phx-click="select_conversation"
                  phx-value-id={conv.id}
                  class="ai-chat-history-title"
                >
                  {conv.title || "Untitled"}
                </span>
                <button
                  phx-click="delete_conversation"
                  phx-value-id={conv.id}
                  data-confirm="Delete this conversation?"
                  class="ai-chat-history-del"
                >
                  &times;
                </button>
              </div>
            <% end %>
            <%= if @conversations == [] do %>
              <div class="ai-chat-history-empty">No conversations yet</div>
            <% end %>
          </div>
        <% end %>

        <%!-- Messages --%>
        <div
          id="chat-messages"
          phx-hook="ScrollBottom"
          class="ai-chat-messages"
        >
          <%= for msg <- @messages do %>
            <div class={"ai-chat-msg #{if msg.role == "user", do: "ai-chat-msg-user", else: "ai-chat-msg-ai"}"}>
              <div class={"ai-chat-bubble #{if msg.role == "user", do: "ai-chat-bubble-user", else: "ai-chat-bubble-ai"}"}>
                {msg.content}
              </div>
            </div>
          <% end %>

          <%= if @loading do %>
            <div class="ai-chat-msg ai-chat-msg-ai">
              <div class="ai-chat-bubble ai-chat-bubble-ai ai-chat-thinking">
                Thinking...
              </div>
            </div>
          <% end %>

          <%= if @messages == [] and not @loading and @current_conversation do %>
            <div class="ai-chat-empty">
              Ask a question about your portfolio, companies, or financial data.
            </div>
          <% end %>
        </div>

        <%!-- Input --%>
        <div class="ai-chat-input-bar">
          <form phx-submit="send_message" class="ai-chat-form">
            <input
              type="text"
              name="message[content]"
              value={@input}
              phx-keyup="update_input"
              class="ai-chat-input"
              placeholder={if @configured, do: "Ask a question...", else: "AI not configured"}
              autocomplete="off"
              disabled={@loading or not @configured}
            />
            <button
              type="submit"
              class="ai-chat-send"
              disabled={@loading or @input == "" or not @configured}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
