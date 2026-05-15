defmodule AutoMyInvoice.AI.VisionClientTest do
  @moduledoc """
  Unit tests for the pure helpers in `AutoMyInvoice.AI.VisionClient`.

  Covers AC-6 from .hermes/seeds/AMI-84.md. Helpers exercised here are
  exposed as `def` (originally `defp`) with `@doc false` specifically so
  they can be unit tested without mocking the OpenAI HTTP layer.
  """

  use ExUnit.Case

  alias AutoMyInvoice.AI.VisionClient

  describe "extract/2 API key guard" do
    test "returns error when API key is not configured" do
      original = Application.get_env(:auto_my_invoice, :openai_api_key)
      Application.put_env(:auto_my_invoice, :openai_api_key, nil)

      result = VisionClient.extract("/tmp/nonexistent.png", "png")

      Application.put_env(:auto_my_invoice, :openai_api_key, original)

      assert {:error, "OPENAI_API_KEY not configured"} = result
    end

    test "returns error when API key is empty string" do
      original = Application.get_env(:auto_my_invoice, :openai_api_key)
      Application.put_env(:auto_my_invoice, :openai_api_key, "")

      result = VisionClient.extract("/tmp/nonexistent.png", "png")

      Application.put_env(:auto_my_invoice, :openai_api_key, original)

      assert {:error, "OPENAI_API_KEY not configured"} = result
    end
  end

  describe "parse_confidence/1" do
    test "nil falls back to 0.5" do
      assert VisionClient.parse_confidence(nil) == 0.5
    end

    test "valid float in [0.0, 1.0] is preserved" do
      assert VisionClient.parse_confidence(0.85) == 0.85
      assert VisionClient.parse_confidence(0.0) == 0.0
      assert VisionClient.parse_confidence(1.0) == 1.0
    end

    test "integer is coerced to float" do
      assert VisionClient.parse_confidence(1) == 1.0
      assert VisionClient.parse_confidence(0) == 0.0
    end

    test "values above 1.0 clamp to 1.0" do
      assert VisionClient.parse_confidence(1.5) == 1.0
      assert VisionClient.parse_confidence(99) == 1.0
    end

    test "values below 0.0 clamp to 0.0" do
      assert VisionClient.parse_confidence(-0.3) == 0.0
      assert VisionClient.parse_confidence(-42) == 0.0
    end

    test "non-numeric input falls back to 0.5" do
      assert VisionClient.parse_confidence("high") == 0.5
      assert VisionClient.parse_confidence(%{}) == 0.5
      assert VisionClient.parse_confidence([]) == 0.5
    end
  end

  describe "strip_markdown_fences/1" do
    test "removes ```json opening and ``` closing fences" do
      input = "```json\n{\"amount\":\"100\"}\n```"
      assert VisionClient.strip_markdown_fences(input) == "{\"amount\":\"100\"}"
    end

    test "is case-insensitive on the opening fence" do
      assert VisionClient.strip_markdown_fences("```JSON\n{\"a\":1}\n```") =~ "{\"a\":1}"
    end

    test "leaves raw JSON without fences unchanged" do
      raw = "{\"amount\":\"100\"}"
      assert VisionClient.strip_markdown_fences(raw) == raw
    end
  end

  describe "parse_response/1" do
    test "success path extracts data and confidence, removing confidence from extracted_data" do
      raw = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"amount":"1500.00","currency":"KRW","confidence":0.9})
            }
          }
        ]
      }

      assert {:ok, %{raw_response: ^raw, extracted_data: extracted, confidence: 0.9}} =
               VisionClient.parse_response(raw)

      assert extracted == %{"amount" => "1500.00", "currency" => "KRW"}
      refute Map.has_key?(extracted, "confidence")
    end

    test "success path tolerates markdown-fenced JSON in the content" do
      raw = %{
        "choices" => [
          %{
            "message" => %{
              "content" => "```json\n{\"amount\":\"100\",\"confidence\":1.0}\n```"
            }
          }
        ]
      }

      assert {:ok, %{extracted_data: %{"amount" => "100"}, confidence: 1.0}} =
               VisionClient.parse_response(raw)
    end

    test "missing confidence defaults to 0.5" do
      raw = %{
        "choices" => [%{"message" => %{"content" => ~s({"amount":"50"})}}]
      }

      assert {:ok, %{confidence: 0.5}} = VisionClient.parse_response(raw)
    end

    test "malformed JSON content returns {:error, _}" do
      raw = %{"choices" => [%{"message" => %{"content" => "not valid json"}}]}

      assert {:error, msg} = VisionClient.parse_response(raw)
      assert msg =~ "Failed to parse"
    end

    test "unexpected response shape returns {:error, _}" do
      assert {:error, msg} = VisionClient.parse_response(%{"something" => "else"})
      assert msg =~ "Unexpected API response"
    end
  end
end
