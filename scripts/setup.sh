#!/usr/bin/env bash
set -euo pipefail

echo "=== InvoiceFlow Development Setup ==="

# Check prerequisites
command -v elixir >/dev/null 2>&1 || { echo "Elixir is required but not installed."; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "PostgreSQL is required but not installed."; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node.js is required but not installed."; exit 1; }

echo "✓ Prerequisites found"

# Install dependencies
echo "Installing Elixir dependencies..."
mix deps.get

# Setup database
echo "Setting up database..."
mix ecto.setup

# Setup assets
echo "Setting up assets..."
mix assets.setup
mix assets.build

echo ""
echo "=== Setup Complete ==="
echo "Run 'make server' to start the development server"
