.PHONY: help new-app lint lint-fix

# template-init:start
.PHONY: init-repo
# template-init:end

MAKEFLAGS += --silent
.DEFAULT_GOAL := help

help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# template-init:start
init-repo: ## Initialize a repository created from this template (usage: make init-repo GITHUB_ORG=my-org BASE_DOMAIN=example.com DEV_CLUSTER_URL=https://dev.example.com PROD_CLUSTER_URL=https://prod.example.com [REPO_NAME=my-repo] [DRY_RUN=1])
	@if [ ! -f scripts/init_repo.sh ]; then \
		echo "Repository already initialized: scripts/init_repo.sh has been removed."; \
		exit 0; \
	fi
	@if [ -z "$(GITHUB_ORG)" ]; then \
		echo "GITHUB_ORG is required"; \
		echo "Example: make init-repo GITHUB_ORG=my-org BASE_DOMAIN=example.com"; \
		exit 1; \
	fi
	@if [ -z "$(BASE_DOMAIN)" ]; then \
		echo "BASE_DOMAIN is required"; \
		echo "Example: make init-repo GITHUB_ORG=my-org BASE_DOMAIN=example.com DEV_CLUSTER_URL=https://dev.example.com PROD_CLUSTER_URL=https://prod.example.com"; \
		exit 1; \
	fi
	@if [ -z "$(DEV_CLUSTER_URL)" ]; then \
		echo "DEV_CLUSTER_URL is required"; \
		echo "Example: make init-repo GITHUB_ORG=my-org BASE_DOMAIN=example.com DEV_CLUSTER_URL=https://dev.example.com PROD_CLUSTER_URL=https://prod.example.com"; \
		exit 1; \
	fi
	@if [ -z "$(PROD_CLUSTER_URL)" ]; then \
		echo "PROD_CLUSTER_URL is required"; \
		echo "Example: make init-repo GITHUB_ORG=my-org BASE_DOMAIN=example.com DEV_CLUSTER_URL=https://dev.example.com PROD_CLUSTER_URL=https://prod.example.com"; \
		exit 1; \
	fi
	sh scripts/init_repo.sh \
		--github-org "$(GITHUB_ORG)" \
		--base-domain "$(BASE_DOMAIN)" \
		--dev-cluster-url "$(DEV_CLUSTER_URL)" \
		--prod-cluster-url "$(PROD_CLUSTER_URL)" \
		$(if $(REPO_NAME),--repo-name "$(REPO_NAME)",) \
		$(if $(DRY_RUN),--dry-run,)
# template-init:end

new-app: ## Scaffold a new app across dev, UAT, and production (usage: make new-app APP_NAME=my-app [DRY_RUN=1])
	@if [ -z "$(APP_NAME)" ]; then \
		echo "APP_NAME is required"; \
		echo "Example: make new-app APP_NAME=my-app"; \
		exit 1; \
	fi
	sh scripts/create_dev_app.sh \
		--new-app "$(APP_NAME)" \
		$(if $(DRY_RUN),--dry-run,)

lint: ## Execute linting
	$(call run_linter,)

lint-fix: ## Execute linting and fix
	$(call run_linter, \
		-e FIX_SPELL_CODESPELL=true \
		-e FIX_MARKDOWN=true \
		-e FIX_MARKDOWN_PRETTIER=true \
		-e FIX_YAML_PRETTIER=true \
		-e FIX_NATURAL_LANGUAGE=true \
		-e FIX_SHELL_SHFMT=true \
		-e FIX_BIOME_LINT=true \
		-e FIX_BIOME_FORMAT=true \
	)

define run_linter
	DEFAULT_WORKSPACE="$(CURDIR)"; \
	LINTER_IMAGE="linter:latest"; \
	VOLUME="$$DEFAULT_WORKSPACE:$$DEFAULT_WORKSPACE"; \
	docker build --build-arg UID=$(shell id -u) --build-arg GID=$(shell id -g) --tag $$LINTER_IMAGE .; \
	docker run \
		-e DEFAULT_WORKSPACE="$$DEFAULT_WORKSPACE" \
		-e FILTER_REGEX_INCLUDE="$(filter-out $@,$(MAKECMDGOALS))" \
		$(1) \
		-v $$VOLUME \
		--rm \
		$$LINTER_IMAGE
endef

define docker-compose
    COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose -f docker-compose.yml -f docker-compose.local.yml -f docker-compose.$(1).yml $(2)
endef

define open-in-browser
	@if command -v x-www-browser &> /dev/null ; then x-www-browser $(1); \
	elif command -v xdg-open &> /dev/null ; then xdg-open $(1); \
	elif command -v open &> /dev/null ; then open $(1); \
	elif command -v start &> /dev/null ; then	start $(1);	fi;
endef

#############################
# Argument fix workaround
#############################
%:
	@:
