.PHONY: help server test api-test format lint setup \
        docker.build docker.setup docker.test docker.precommit docker.server docker.psql docker.shell docker.down

help: ## Show available commands
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

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
	mix test test/auto_my_invoice_web/controllers/api/

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

# ───────────────────────────── Docker workflow ─────────────────────────────
# Host has no native Elixir/Mix/Postgres → use the Docker compose stack.
# All commands respect UID/GID from .env so files stay user-owned.

DC := UID=$(shell id -u) GID=$(shell id -g) docker compose

docker.build: ## Build the dev image
	$(DC) build app

docker.setup: ## Run `mix setup` inside the container
	$(DC) run --rm app mix setup

docker.test: ## Run the full test suite inside the container
	$(DC) run --rm -e MIX_ENV=test app mix test

docker.precommit: ## Run `mix precommit` inside the container
	$(DC) run --rm -e MIX_ENV=test app mix precommit

docker.server: ## Start Phoenix on host port $$PHX_PORT (default 4000)
	$(DC) up -d db
	$(DC) run --rm --service-ports app mix phx.server

docker.psql: ## Open psql in the dev database
	$(DC) exec db psql -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-auto_my_invoice_dev}

docker.shell: ## Drop into a bash shell inside the app container
	$(DC) run --rm app bash

docker.down: ## Stop all compose services
	$(DC) down
