defmodule AutoMyInvoice.AI.VisionClient do
  @moduledoc """
  OpenAI GPT-4o Vision API client for invoice data extraction.
  Sends an image/PDF to the API and returns structured invoice data.
  """

  @extraction_prompt """
  You are an invoice data extraction assistant. Analyze the provided invoice image and extract the following information in JSON format:

  {
    "invoice_number": "string or null",
    "amount": "string (numeric, no currency symbol)",
    "currency": "string (ISO 4217 code, e.g. USD, EUR, KRW)",
    "due_date": "string (ISO 8601 date, e.g. 2026-04-15) or null",
    "issue_date": "string (ISO 8601 date) or null",
    "client_name": "string or null",
    "client_email": "string or null",
    "client_company": "string or null",
    "notes": "string or null",
    "items": [
      {
        "description": "string",
        "quantity": "string (numeric)",
        "unit_price": "string (numeric, no currency symbol)"
      }
    ],
    "confidence": 0.0 to 1.0
  }

  Rules:
  - Extract ALL line items if visible
  - Use ISO 8601 date format (YYYY-MM-DD)
  - Remove currency symbols from amounts (e.g. "$1,500.00" -> "1500.00")
  - If a field is not found, use null
  - Set confidence based on how clearly the data was readable (1.0 = perfect, 0.5 = partial, 0.0 = unreadable)
  - Return ONLY valid JSON, no markdown or explanation
  """

  @spec extract(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def extract(file_path, file_type) do
    api_key = Application.get_env(:auto_my_invoice, :openai_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, "OPENAI_API_KEY not configured"}
    else
      do_extract(file_path, file_type, api_key)
    end
  end

  defp do_extract(file_path, file_type, api_key) do
    content = build_content(file_path, file_type)

    body = %{
      model: "gpt-4o",
      messages: [
        %{role: "system", content: @extraction_prompt},
        %{role: "user", content: content}
      ],
      max_tokens: 2000,
      temperature: 0.1
    }

    case Req.post("https://api.openai.com/v1/chat/completions",
           json: body,
           headers: [{"authorization", "Bearer #{api_key}"}],
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: response_body}} ->
        parse_response(response_body)

      {:ok, %{status: status, body: body}} ->
        {:error, "OpenAI API error (#{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp build_content(file_path, file_type) do
    abs_path =
      if String.starts_with?(file_path, "/") do
        file_path
      else
        Path.join(File.cwd!(), file_path)
      end

    case File.read(abs_path) do
      {:ok, binary} ->
        base64 = Base.encode64(binary)
        media_type = media_type(file_type)

        [
          %{
            type: "image_url",
            image_url: %{
              url: "data:#{media_type};base64,#{base64}",
              detail: "high"
            }
          },
          %{type: "text", text: "Extract all invoice data from this document."}
        ]

      {:error, reason} ->
        [
          %{
            type: "text",
            text: "Error reading file: #{inspect(reason)}. Please provide invoice details."
          }
        ]
    end
  end

  defp media_type("pdf"), do: "application/pdf"
  defp media_type("jpg"), do: "image/jpeg"
  defp media_type("jpeg"), do: "image/jpeg"
  defp media_type("png"), do: "image/png"
  defp media_type(_), do: "application/octet-stream"

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]} = raw) do
    cleaned = content |> String.trim() |> strip_markdown_fences()

    case Jason.decode(cleaned) do
      {:ok, data} ->
        confidence = parse_confidence(data["confidence"])
        extracted = Map.delete(data, "confidence")
        {:ok, %{raw_response: raw, extracted_data: extracted, confidence: confidence}}

      {:error, _} ->
        {:error, "Failed to parse AI response as JSON: #{String.slice(content, 0..200)}"}
    end
  end

  defp parse_response(raw) do
    {:error, "Unexpected API response format: #{inspect(raw) |> String.slice(0..200)}"}
  end

  defp strip_markdown_fences(text) do
    text
    |> String.replace(~r/^```json\s*/i, "")
    |> String.replace(~r/\s*```$/, "")
  end

  defp parse_confidence(nil), do: 0.5
  defp parse_confidence(c) when is_float(c), do: min(max(c, 0.0), 1.0)
  defp parse_confidence(c) when is_integer(c), do: min(max(c / 1.0, 0.0), 1.0)
  defp parse_confidence(_), do: 0.5
end
