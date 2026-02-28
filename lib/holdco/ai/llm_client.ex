defmodule Holdco.AI.LLMClient do
  @moduledoc """
  HTTP wrapper for LLM provider APIs.
  """

  def call(:anthropic, messages, config) do
    Req.post("https://api.anthropic.com/v1/messages",
      json: %{
        model: config.model,
        max_tokens: 4096,
        system: config.system_prompt,
        messages: messages
      },
      headers: [
        {"x-api-key", config.api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ],
      receive_timeout: 60_000
    )
    |> parse_anthropic_response()
  end

  def call(:openai, messages, config) do
    system_msg = %{"role" => "system", "content" => config.system_prompt}

    Req.post("https://api.openai.com/v1/chat/completions",
      json: %{
        model: config.model,
        messages: [system_msg | messages]
      },
      headers: [
        {"authorization", "Bearer #{config.api_key}"},
        {"content-type", "application/json"}
      ],
      receive_timeout: 60_000
    )
    |> parse_openai_response()
  end

  def call(provider, _messages, _config) do
    {:error, "Unknown provider: #{provider}"}
  end

  def test_connection(:anthropic, api_key, model) do
    call(:anthropic, [%{"role" => "user", "content" => "Say OK"}], %{
      api_key: api_key,
      model: model,
      system_prompt: "Respond with OK only."
    })
  end

  def test_connection(:openai, api_key, model) do
    call(:openai, [%{"role" => "user", "content" => "Say OK"}], %{
      api_key: api_key,
      model: model,
      system_prompt: "Respond with OK only."
    })
  end

  def test_connection(_, _, _), do: {:error, "Unknown provider"}

  defp parse_anthropic_response({:ok, %{status: 200, body: body}}) do
    content =
      body
      |> Map.get("content", [])
      |> Enum.filter(&(&1["type"] == "text"))
      |> Enum.map_join("\n", & &1["text"])

    {:ok, content}
  end

  defp parse_anthropic_response({:ok, %{status: status, body: body}}) when is_map(body) do
    error = get_in(body, ["error", "message"]) || "HTTP #{status}"
    {:error, error}
  end

  defp parse_anthropic_response({:ok, %{status: status, body: body}}) when is_binary(body) do
    {:error, "HTTP #{status}: #{String.slice(body, 0, 200)}"}
  end

  defp parse_anthropic_response({:error, reason}) do
    {:error, "Request failed: #{inspect(reason)}"}
  end

  defp parse_openai_response({:ok, %{status: 200, body: body}}) do
    content =
      body
      |> get_in(["choices", Access.at(0), "message", "content"])

    {:ok, content || ""}
  end

  defp parse_openai_response({:ok, %{status: status, body: body}}) when is_map(body) do
    error = get_in(body, ["error", "message"]) || "HTTP #{status}"
    {:error, error}
  end

  defp parse_openai_response({:ok, %{status: status, body: body}}) when is_binary(body) do
    {:error, "HTTP #{status}: #{String.slice(body, 0, 200)}"}
  end

  defp parse_openai_response({:error, reason}) do
    {:error, "Request failed: #{inspect(reason)}"}
  end
end
