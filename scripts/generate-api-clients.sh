#!/usr/bin/env bash
set -euo pipefail

SPEC_FILE="packages/api-spec/openapi.yaml"

if [ ! -f "$SPEC_FILE" ]; then
  echo "Error: OpenAPI spec not found at $SPEC_FILE"
  exit 1
fi

echo "=== Generating API Clients ==="

# Android (Kotlin)
if command -v openapi-generator-cli >/dev/null 2>&1; then
  echo "Generating Kotlin client..."
  openapi-generator-cli generate \
    -i "$SPEC_FILE" \
    -g kotlin \
    -o apps/android/app/src/main/java/com/invoiceflow/data/remote/generated \
    --additional-properties=library=jvm-retrofit2,serializationLibrary=kotlinx_serialization

  echo "Generating Swift client..."
  openapi-generator-cli generate \
    -i "$SPEC_FILE" \
    -g swift5 \
    -o apps/ios/InvoiceFlow/Core/Network/Generated \
    --additional-properties=responseAs=AsyncAwait
else
  echo "openapi-generator-cli not found. Install with: brew install openapi-generator"
  exit 1
fi

echo "=== API Clients Generated ==="
