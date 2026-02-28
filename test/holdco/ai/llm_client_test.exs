defmodule Holdco.AI.LLMClientTest do
  use ExUnit.Case, async: true

  alias Holdco.AI.LLMClient

  # ── call/3 ─────────────────────────────────────────────────────

  describe "call/3 with unknown provider" do
    test "returns error with provider name in message" do
      assert {:error, msg} = LLMClient.call(:unknown, [], %{})
      assert msg =~ "Unknown provider"
      assert msg =~ "unknown"
    end

    test "returns error for atom provider" do
      assert {:error, msg} = LLMClient.call(:gemini, [], %{})
      assert msg =~ "gemini"
    end

    test "returns error for string provider" do
      assert {:error, msg} = LLMClient.call("something", [], %{})
      assert msg =~ "something"
    end
  end

  describe "call/3 with :anthropic provider (network errors)" do
    test "returns error when API is unreachable with invalid key" do
      config = %{
        api_key: "sk-ant-invalid-test-key",
        model: "claude-sonnet-4-20250514",
        system_prompt: "You are a test."
      }

      messages = [%{"role" => "user", "content" => "Hello"}]
      result = LLMClient.call(:anthropic, messages, config)
      assert {:error, _reason} = result
    end
  end

  describe "call/3 with :openai provider (network errors)" do
    test "returns error when API is unreachable with invalid key" do
      config = %{
        api_key: "sk-invalid-openai-key",
        model: "gpt-4",
        system_prompt: "You are a test."
      }

      messages = [%{"role" => "user", "content" => "Hello"}]
      result = LLMClient.call(:openai, messages, config)
      assert {:error, _reason} = result
    end
  end

  # ── test_connection/3 ──────────────────────────────────────────

  describe "test_connection/3" do
    test "returns error for unknown provider" do
      assert {:error, "Unknown provider"} =
               LLMClient.test_connection(:unknown, "key", "model")
    end

    test "returns error for nil provider" do
      assert {:error, "Unknown provider"} =
               LLMClient.test_connection(nil, "key", "model")
    end

    test "anthropic test_connection calls call/3 and returns error with invalid key" do
      result = LLMClient.test_connection(:anthropic, "sk-ant-invalid", "claude-sonnet-4-20250514")
      assert {:error, _reason} = result
    end

    test "openai test_connection calls call/3 and returns error with invalid key" do
      result = LLMClient.test_connection(:openai, "sk-invalid", "gpt-4")
      assert {:error, _reason} = result
    end
  end

  # ── parse_anthropic_response (private, tested via call/3 behavior) ──
  # We test the parsing logic by simulating the response shapes that
  # call/3 would receive. Since the functions are private, we test them
  # indirectly through the public call/3 function's behavior with real
  # HTTP responses.

  describe "Anthropic response parsing (integration)" do
    test "handles HTTP error status from anthropic" do
      # When Anthropic returns a non-200 status, call/3 should extract the error message
      # We test this with an invalid API key which will return 401
      config = %{
        api_key: "sk-ant-test-invalid",
        model: "claude-sonnet-4-20250514",
        system_prompt: "Test"
      }

      result = LLMClient.call(:anthropic, [%{"role" => "user", "content" => "test"}], config)
      assert {:error, error_msg} = result
      assert is_binary(error_msg)
    end
  end

  describe "OpenAI response parsing (integration)" do
    test "handles HTTP error status from openai" do
      config = %{
        api_key: "sk-invalid-openai",
        model: "gpt-4",
        system_prompt: "Test"
      }

      result = LLMClient.call(:openai, [%{"role" => "user", "content" => "test"}], config)
      assert {:error, error_msg} = result
      assert is_binary(error_msg)
    end
  end

  # ── Parse response testing via module internals ─────────────────
  # Since parse_anthropic_response and parse_openai_response are private,
  # we test them by calling the module's internal functions via
  # :erlang.apply or by simulating the exact shapes that Req returns.
  # The simplest approach: use Mox or just test via the public API with
  # known error responses.

  describe "Anthropic response shapes" do
    test "call/3 with anthropic returns error string for non-200 with map body" do
      # This exercises parse_anthropic_response({:ok, %{status: 401, body: %{...}}})
      # when the Anthropic API returns a JSON error body
      config = %{
        api_key: "sk-ant-test-key-that-returns-401",
        model: "claude-sonnet-4-20250514",
        system_prompt: "Test"
      }

      result = LLMClient.call(:anthropic, [%{"role" => "user", "content" => "hi"}], config)
      assert {:error, msg} = result
      assert is_binary(msg)
    end
  end

  describe "OpenAI response shapes" do
    test "call/3 with openai returns error string for non-200 with map body" do
      config = %{
        api_key: "sk-bad-openai-key",
        model: "gpt-4",
        system_prompt: "Test"
      }

      result = LLMClient.call(:openai, [%{"role" => "user", "content" => "hi"}], config)
      assert {:error, msg} = result
      assert is_binary(msg)
    end
  end

  describe "call/3 edge cases" do
    test "returns error for integer provider" do
      assert {:error, msg} = LLMClient.call(42, [], %{})
      assert msg =~ "42"
    end

    test "returns error for nil provider" do
      assert {:error, msg} = LLMClient.call(nil, [], %{})
      assert msg =~ "Unknown provider"
    end

    test "anthropic test_connection with empty string key" do
      result = LLMClient.test_connection(:anthropic, "", "claude-sonnet-4-20250514")
      assert {:error, _} = result
    end

    test "openai test_connection with empty string key" do
      result = LLMClient.test_connection(:openai, "", "gpt-4")
      assert {:error, _} = result
    end
  end
end
