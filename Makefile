LINTER_IMAGE ?= argocd-app-of-apps-template-linter:local
FILTER ?= $(or $(filter-out lint lint-fix,$(MAKECMDGOALS)),.*)

.DEFAULT_GOAL := help
.PHONY: help lint lint-fix

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# template-init:start
.PHONY: init-repo
# template-init:end
.PHONY: new-app

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

lint: ## Run the repository lint checks (optional FILTER=regex)
	$(call run_linter,)

lint-fix: ## Apply supported automatic lint fixes (optional FILTER=regex)
	$(call run_linter, \
		-e FIX_BIOME_LINT=true \
		-e FIX_BIOME_FORMAT=true \
		-e FIX_MARKDOWN=true \
		-e FIX_MARKDOWN_PRETTIER=true \
		-e FIX_YAML_PRETTIER=true \
		-e FIX_NATURAL_LANGUAGE=true \
		-e FIX_SHELL_SHFMT=true \
		-e FIX_SPELL_CODESPELL=true \
	)

define run_linter
	@set -eu; \
	git_common_dir="$$(git rev-parse --path-format=absolute --git-common-dir)"; \
	docker build --platform linux/amd64 --target linter \
		--build-arg UID="$$(id -u)" --build-arg GID="$$(id -g)" \
		--tag "$(LINTER_IMAGE)" .; \
	docker run --platform linux/amd64 --rm \
		--volume "$(CURDIR):$(CURDIR)" \
		--volume "$$git_common_dir:$$git_common_dir:ro" \
		-e DEFAULT_WORKSPACE="$(CURDIR)" \
		-e FILTER_REGEX_INCLUDE="$(FILTER)" \
		$(1) \
		"$(LINTER_IMAGE)"
endef

# Allow the shared "make lint <pattern>" interface without hiding other target typos.
ifneq ($(filter lint lint-fix,$(MAKECMDGOALS)),)
%:
	@:
endif
