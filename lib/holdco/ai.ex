defmodule Holdco.AI do
  @moduledoc """
  Context module for AI/LLM operations: configuration, chat, and conversation CRUD.
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Platform
  alias Holdco.AI.{Conversation, Message, LLMClient, DataContext}

  # --- Configuration ---

  def get_config do
    %{
      provider: parse_provider(Platform.get_setting_value("llm_provider")),
      api_key: Platform.get_setting_value("llm_api_key"),
      model: Platform.get_setting_value("llm_model", default_model())
    }
  end

  def configured? do
    config = get_config()
    config.provider != nil and config.api_key != nil and config.api_key != ""
  end

  defp parse_provider("anthropic"), do: :anthropic
  defp parse_provider("openai"), do: :openai
  defp parse_provider(_), do: nil

  defp default_model, do: "claude-sonnet-4-20250514"

  # --- Chat ---

  def chat(messages, opts \\ []) do
    config = get_config()

    unless config.provider do
      {:error, "LLM provider not configured. Go to Settings → AI to set up."}
    else
      system_prompt = Keyword.get(opts, :system_prompt, build_system_prompt())

      LLMClient.call(config.provider, messages, %{
        api_key: config.api_key,
        model: config.model,
        system_prompt: system_prompt
      })
    end
  end

  def generate_insights(data_context) do
    config = get_config()

    unless config.provider do
      {:error, "LLM not configured"}
    else
      prompt = """
      You are a portfolio analyst. Based on the data below, provide 2-3 brief, actionable insights \
      about the portfolio's health, risks, or opportunities. Be concise (max 150 words total). \
      Use bullet points.

      #{data_context}
      """

      LLMClient.call(config.provider, [%{"role" => "user", "content" => "Provide insights."}], %{
        api_key: config.api_key,
        model: config.model,
        system_prompt: prompt
      })
    end
  end

  def test_connection do
    config = get_config()

    unless config.provider do
      {:error, "Provider not configured"}
    else
      LLMClient.test_connection(config.provider, config.api_key, config.model)
    end
  end

  def build_system_prompt do
    data = DataContext.build_summary()

    """
    You are a financial analyst assistant for a holding company management platform called Holdco. \
    You have access to the following live portfolio data. Use it to answer questions accurately.

    #{data}

    Guidelines:
    - Answer based on the data provided. If the data doesn't contain what's needed, say so.
    - Be concise and professional.
    - When discussing money, always specify the currency.
    - Format numbers with commas for readability.
    """
  end

  # --- Conversation CRUD ---

  def list_conversations(user_id) do
    from(c in Conversation,
      where: c.user_id == ^user_id,
      order_by: [desc: c.updated_at]
    )
    |> Repo.all()
  end

  def get_conversation!(id) do
    Repo.get!(Conversation, id)
    |> Repo.preload(messages: from(m in Message, order_by: m.inserted_at))
  end

  def create_conversation(attrs) do
    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  def delete_conversation(id) do
    Repo.get!(Conversation, id) |> Repo.delete()
  end

  def update_conversation_title(conversation, title) do
    conversation
    |> Conversation.changeset(%{title: title})
    |> Repo.update()
  end

  # --- Message CRUD ---

  def add_message(conversation_id, role, content) do
    %Message{}
    |> Message.changeset(%{conversation_id: conversation_id, role: role, content: content})
    |> Repo.insert()
  end

  def list_messages(conversation_id) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: m.inserted_at
    )
    |> Repo.all()
  end

  def format_messages_for_api(messages) do
    Enum.map(messages, fn m ->
      %{"role" => m.role, "content" => m.content}
    end)
  end
end
