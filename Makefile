.PHONY: help server test api-test format lint setup

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Server
server: ## Start Phoenix development server
	mix phx.server

iex: ## Start interactive Elixir shell with Phoenix
	iex -S mix phx.server

# Database
db.setup: ## Create and migrate database
	mix ecto.setup

db.migrate: ## Run pending migrations
	mix ecto.migrate

db.reset: ## Drop, create and migrate database
	mix ecto.reset

# Testing
test: ## Run all tests
	mix test

test.watch: ## Run tests in watch mode
	mix test --stale

api-test: ## Run API controller tests only
	mix test test/invoice_flow_web/controllers/api/

# Code Quality
format: ## Format code
	mix format

format.check: ## Check code formatting
	mix format --check-formatted

lint: ## Run Credo linter
	mix credo --strict

dialyzer: ## Run Dialyzer type checker
	mix dialyzer

# Setup
setup: ## Initial project setup
	mix setup

deps: ## Get dependencies
	mix deps.get

# CI
precommit: ## Run precommit checks (compile, format, test)
	mix precommit

# API Spec
api-spec.validate: ## Validate OpenAPI spec
	@echo "TODO: Add OpenAPI spec validation"
