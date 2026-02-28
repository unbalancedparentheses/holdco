defmodule HoldcoWeb.AiChatLiveTest do
  use HoldcoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  # Helper to get the sticky AI chat child LiveView from any page
  defp get_chat_view(conn) do
    {:ok, parent_view, _html} = live(conn, ~p"/")
    chat_view = find_live_child(parent_view, "ai-chat-drawer")
    {parent_view, chat_view}
  end

  # ------------------------------------------------------------------
  # Mount and render
  # ------------------------------------------------------------------

  describe "mount" do
    test "AI chat drawer renders within the layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "ai-chat-drawer-inner"
    end

    test "FAB button is visible when chat is closed", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "ai-chat-fab"
      assert html =~ "Open AI Chat"
    end
  end

  # ------------------------------------------------------------------
  # toggle_chat
  # ------------------------------------------------------------------

  describe "toggle_chat" do
    test "clicking FAB opens the chat panel", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      html = render_click(chat_view, "toggle_chat", %{})
      assert html =~ "ai-chat-panel-open"
      assert html =~ "AI Chat"
    end

    test "clicking close button closes the chat panel", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      # Open first
      render_click(chat_view, "toggle_chat", %{})
      # Close
      html = render_click(chat_view, "toggle_chat", %{})
      refute html =~ "ai-chat-panel-open"
    end
  end

  # ------------------------------------------------------------------
  # toggle_history
  # ------------------------------------------------------------------

  describe "toggle_history" do
    test "toggle_history shows conversation history", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      # Open chat first
      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "toggle_history", %{})
      assert html =~ "ai-chat-history"
    end

    test "toggle_history again hides history", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      render_click(chat_view, "toggle_history", %{})
      html = render_click(chat_view, "toggle_history", %{})
      refute html =~ "ai-chat-history"
    end

    test "empty history shows No conversations yet", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "toggle_history", %{})
      assert html =~ "No conversations yet"
    end
  end

  # ------------------------------------------------------------------
  # new_conversation
  # ------------------------------------------------------------------

  describe "new_conversation" do
    test "creates a new conversation", %{conn: conn, user: user} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "new_conversation", %{})

      # Should have created a conversation and it should be visible
      conversations = Holdco.AI.list_conversations(user.id)
      assert length(conversations) >= 1

      # History should be hidden after new conversation
      refute html =~ "ai-chat-history"
    end
  end

  # ------------------------------------------------------------------
  # select_conversation
  # ------------------------------------------------------------------

  describe "select_conversation" do
    test "selecting a conversation loads its messages", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Test Conv"})
      Holdco.AI.add_message(conv.id, "user", "Hello there")
      Holdco.AI.add_message(conv.id, "assistant", "Hi! How can I help?")

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      assert html =~ "Hello there"
      assert html =~ "Hi! How can I help?"
    end
  end

  # ------------------------------------------------------------------
  # delete_conversation
  # ------------------------------------------------------------------

  describe "delete_conversation" do
    test "deleting a conversation removes it from the list", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Deletable Conv"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      render_click(chat_view, "toggle_history", %{})
      html = render_click(chat_view, "delete_conversation", %{"id" => to_string(conv.id)})

      refute html =~ "Deletable Conv"
    end

    test "deleting current conversation clears messages", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Current Conv"})
      Holdco.AI.add_message(conv.id, "user", "Some message")

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      # Select the conversation first
      render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      # Delete it
      html = render_click(chat_view, "delete_conversation", %{"id" => to_string(conv.id)})

      refute html =~ "Some message"
    end
  end

  # ------------------------------------------------------------------
  # update_input
  # ------------------------------------------------------------------

  describe "update_input" do
    test "updating input stores the value", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "update_input", %{"value" => "test input"})
      assert html =~ "test input"
    end
  end

  # ------------------------------------------------------------------
  # send_message with empty input
  # ------------------------------------------------------------------

  describe "send_message" do
    test "send_message with empty content does nothing", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "send_message", %{"message" => %{"content" => ""}})

      # Should not crash, no loading indicator
      refute html =~ "Thinking..."
    end

    test "send_message with whitespace-only content does nothing", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "send_message", %{"message" => %{"content" => "   "}})

      refute html =~ "Thinking..."
    end

    test "send_message with no message params does nothing", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "send_message", %{})

      # Fallback handler, should not crash
      assert html =~ "ai-chat-drawer-inner"
    end
  end

  # ------------------------------------------------------------------
  # AI not configured notice
  # ------------------------------------------------------------------

  describe "AI not configured" do
    test "shows configuration notice when AI is not configured", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      html = render_click(chat_view, "toggle_chat", %{})
      assert html =~ "AI provider not configured"
      assert html =~ "Configure in Settings"
    end

    test "input is disabled when AI is not configured", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      html = render_click(chat_view, "toggle_chat", %{})
      assert html =~ "AI not configured"
      assert html =~ "disabled"
    end
  end

  # ------------------------------------------------------------------
  # handle_info
  # ------------------------------------------------------------------

  describe "handle_info" do
    test "unknown message does not crash the view", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      send(chat_view.pid, :some_unknown_event)
      html = render(chat_view)
      assert html =~ "ai-chat-drawer-inner"
    end
  end

  # ------------------------------------------------------------------
  # Conversation title display
  # ------------------------------------------------------------------

  describe "conversation title" do
    test "shows conversation title when a non-default conversation is selected", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Portfolio Review Q1"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      assert html =~ "Portfolio Review Q1"
      assert html =~ "ai-chat-conv-title"
    end

    test "does not show conv title when title is 'New conversation'", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "New conversation"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      refute html =~ "ai-chat-conv-title"
    end
  end

  # ------------------------------------------------------------------
  # Empty chat state
  # ------------------------------------------------------------------

  describe "empty chat state" do
    test "shows helpful prompt when conversation has no messages", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Empty Conv"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      assert html =~ "Ask a question about your portfolio"
    end
  end

  # ------------------------------------------------------------------
  # Message rendering
  # ------------------------------------------------------------------

  describe "message rendering" do
    test "user messages have user bubble class", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Style Conv"})
      Holdco.AI.add_message(conv.id, "user", "User says hello")

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      assert html =~ "ai-chat-msg-user"
      assert html =~ "ai-chat-bubble-user"
      assert html =~ "User says hello"
    end

    test "assistant messages have AI bubble class", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "AI Style Conv"})
      Holdco.AI.add_message(conv.id, "assistant", "AI responds here")

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      assert html =~ "ai-chat-msg-ai"
      assert html =~ "ai-chat-bubble-ai"
      assert html =~ "AI responds here"
    end
  end

  # ------------------------------------------------------------------
  # History with multiple conversations
  # ------------------------------------------------------------------

  describe "history with multiple conversations" do
    test "shows all conversations in history panel", %{conn: conn, user: user} do
      {:ok, _conv1} = Holdco.AI.create_conversation(%{user_id: user.id, title: "First Chat"})
      {:ok, _conv2} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Second Chat"})
      {:ok, _conv3} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Third Chat"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "toggle_history", %{})

      assert html =~ "First Chat"
      assert html =~ "Second Chat"
      assert html =~ "Third Chat"
    end

    test "active conversation is highlighted in history", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Active Conv"})
      {:ok, _conv2} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Other Conv"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})
      html = render_click(chat_view, "toggle_history", %{})

      # The active item should have the "active" class
      assert html =~ "active"
    end
  end

  # ------------------------------------------------------------------
  # delete_conversation when it's NOT the current conversation
  # ------------------------------------------------------------------

  describe "delete non-current conversation" do
    test "deleting a conversation that is NOT the current one keeps current intact", %{conn: conn, user: user} do
      {:ok, conv1} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Stay Conv"})
      {:ok, conv2} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Delete Other Conv"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      # Select conv1 as current
      render_click(chat_view, "select_conversation", %{"id" => to_string(conv1.id)})
      # Delete conv2 (not the current one)
      html = render_click(chat_view, "delete_conversation", %{"id" => to_string(conv2.id)})

      # conv2 should be gone from history, but current conv messages should remain
      refute html =~ "Delete Other Conv"
      # Current conversation should still be active
      assert html =~ "ai-chat-drawer-inner"
    end
  end

  # ------------------------------------------------------------------
  # toggle_chat opens existing conversation
  # ------------------------------------------------------------------

  describe "toggle_chat with existing conversations" do
    test "opening chat panel activates chat open state", %{conn: conn, user: user} do
      {:ok, _conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Latest Conv"})

      {_parent, chat_view} = get_chat_view(conn)

      html = render_click(chat_view, "toggle_chat", %{})
      assert html =~ "ai-chat-panel-open"
      assert html =~ "AI Chat"
    end

    test "selecting a conversation then toggling chat keeps panel state", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Toggle Conv"})
      Holdco.AI.add_message(conv.id, "user", "Toggle message content")

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})
      assert html =~ "Toggle message content"
    end
  end

  # ------------------------------------------------------------------
  # send_message stores the user message in DB
  # ------------------------------------------------------------------

  describe "send_message stores message" do
    test "send_message with actual content stores message and triggers LLM", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "Msg Conv"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      # Send a message
      html = render_click(chat_view, "send_message", %{"message" => %{"content" => "What is my portfolio?"}})

      # Should show the user message and loading indicator
      assert html =~ "What is my portfolio?"
      assert html =~ "Thinking..."

      # The message should have been stored in DB
      messages = Holdco.AI.list_messages(conv.id)
      assert Enum.any?(messages, &(&1.content == "What is my portfolio?"))
    end

    test "first message updates conversation title", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "New conversation"})

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})
      render_click(chat_view, "send_message", %{"message" => %{"content" => "Tell me about my holdings"}})

      # The conversation title should be updated to the first message content
      updated = Holdco.AI.get_conversation!(conv.id)
      assert updated.title == "Tell me about my holdings"
    end
  end

  # ------------------------------------------------------------------
  # handle_info :call_llm
  # ------------------------------------------------------------------

  describe "handle_info :call_llm" do
    test "call_llm handles error from AI.chat gracefully", %{conn: conn, user: user} do
      {:ok, conv} = Holdco.AI.create_conversation(%{user_id: user.id, title: "LLM Error Conv"})
      Holdco.AI.add_message(conv.id, "user", "test question")

      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      render_click(chat_view, "select_conversation", %{"id" => to_string(conv.id)})

      # Send a message which will trigger :call_llm
      render_click(chat_view, "send_message", %{"message" => %{"content" => "test"}})

      # Process the :call_llm message (AI is not configured, so it should error)
      # Give a brief moment for the message to be processed
      :timer.sleep(100)
      html = render(chat_view)

      # Should have exited loading state
      # The AI error flash or the loading=false state should be visible
      assert html =~ "ai-chat-drawer-inner"
    end
  end

  # ------------------------------------------------------------------
  # new_conversation creates a fresh empty conversation
  # ------------------------------------------------------------------

  describe "new_conversation lifecycle" do
    test "new conversation shows empty state prompt", %{conn: conn} do
      {_parent, chat_view} = get_chat_view(conn)

      render_click(chat_view, "toggle_chat", %{})
      html = render_click(chat_view, "new_conversation", %{})

      assert html =~ "Ask a question about your portfolio"
    end
  end
end
