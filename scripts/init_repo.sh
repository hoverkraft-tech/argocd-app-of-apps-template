#!/bin/sh

set -eu

usage() {
	cat <<'EOF'
Usage: init_repo.sh --github-org <github-org> --base-domain <base-domain> --dev-cluster-url <dev-cluster-url> --prod-cluster-url <prod-cluster-url> [--repo-name <repo-name>] [--dry-run]
EOF
}

validate_non_empty() {
	label="$1"
	value="$2"

	if [ -z "$value" ]; then
		echo "$label is required" >&2
		exit 1
	fi
}

validate_repo_name() {
	value="$1"

	if ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._-]+$'; then
		echo "repo-name must contain only letters, numbers, dots, underscores, or dashes, got: $value" >&2
		exit 1
	fi
}

validate_org_name() {
	value="$1"

	if ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9-]+$'; then
		echo "github-org must contain only letters, numbers, or dashes, got: $value" >&2
		exit 1
	fi
}

validate_domain() {
	value="$1"

	if ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9.-]+$'; then
		echo "base-domain must contain only letters, numbers, dots, or dashes, got: $value" >&2
		exit 1
	fi
}

validate_url_value() {
	label="$1"
	value="$2"

	if printf '%s' "$value" | grep -Eq '[[:space:]]'; then
		echo "$label must not contain whitespace, got: $value" >&2
		exit 1
	fi
}

escape_sed_replacement() {
	printf '%s' "$1" | sed 's/[|&\\]/\\&/g'
}

replace_placeholders_in_file() {
	file_path="$1"
	temp_file=$(mktemp)

	sed \
		-e "s|<your-org>|$escaped_github_org|g" \
		-e "s|<your-repo>|$escaped_repo_name|g" \
		-e "s|<your-domain>|$escaped_base_domain|g" \
		-e "s|<url-cluster-dev>|$escaped_dev_cluster_url|g" \
		-e "s|<url-cluster-prod>|$escaped_prod_cluster_url|g" \
		"$file_path" >"$temp_file"
	mv "$temp_file" "$file_path"
}

replace_placeholders_in_tree() {
	target_path="$1"

	find "$target_path" -type f | while IFS= read -r file_path; do
		[ "$file_path" = "$script_path" ] && continue
		replace_placeholders_in_file "$file_path"
	done
}

remove_marked_block() {
	file_path="$1"
	start_marker="$2"
	end_marker="$3"
	temp_file=$(mktemp)

	awk -v start_marker="$start_marker" -v end_marker="$end_marker" '
		$0 == start_marker { skip = 1; next }
		$0 == end_marker { skip = 0; next }
		skip != 1 { print }
	' "$file_path" >"$temp_file"
	mv "$temp_file" "$file_path"
}

cleanup_initialization_artifacts() {
	remove_marked_block "$repo_root/Makefile" '# template-init:start' '# template-init:end'
	remove_marked_block "$repo_root/README.md" '<!-- template-init:start -->' '<!-- template-init:end -->'
}

list_pending_files() {
	printf '%s\n' "$repo_root/Makefile"
	find "$repo_root/README.md" \
		"$repo_root/appsets" \
		"$repo_root/dev" \
		"$repo_root/prod" \
		"$repo_root/templates" \
		-type f \
		-exec grep -lE '<your-org>|<your-repo>|<your-domain>|<url-cluster-dev>|<url-cluster-prod>' {} +
}

github_org=""
base_domain=""
dev_cluster_url=""
prod_cluster_url=""
repo_name=""
dry_run="0"

while [ "$#" -gt 0 ]; do
	case "$1" in
	--github-org)
		shift
		github_org="${1-}"
		;;
	--base-domain)
		shift
		base_domain="${1-}"
		;;
	--dev-cluster-url)
		shift
		dev_cluster_url="${1-}"
		;;
	--prod-cluster-url)
		shift
		prod_cluster_url="${1-}"
		;;
	--repo-name)
		shift
		repo_name="${1-}"
		;;
	--dry-run)
		dry_run="1"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 1
		;;
	esac
	shift
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
script_path="$script_dir/$(basename -- "$0")"
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)

if [ -z "$repo_name" ]; then
	repo_name=$(basename -- "$repo_root")
fi

validate_non_empty "github-org" "$github_org"
validate_non_empty "base-domain" "$base_domain"
validate_non_empty "dev-cluster-url" "$dev_cluster_url"
validate_non_empty "prod-cluster-url" "$prod_cluster_url"
validate_non_empty "repo-name" "$repo_name"
validate_org_name "$github_org"
validate_domain "$base_domain"
validate_url_value "dev-cluster-url" "$dev_cluster_url"
validate_url_value "prod-cluster-url" "$prod_cluster_url"
validate_repo_name "$repo_name"

escaped_github_org=$(escape_sed_replacement "$github_org")
escaped_base_domain=$(escape_sed_replacement "$base_domain")
escaped_dev_cluster_url=$(escape_sed_replacement "$dev_cluster_url")
escaped_prod_cluster_url=$(escape_sed_replacement "$prod_cluster_url")
escaped_repo_name=$(escape_sed_replacement "$repo_name")

if [ "$dry_run" = "1" ]; then
	list_pending_files
	exit 0
fi

replace_placeholders_in_file "$repo_root/README.md"
replace_placeholders_in_tree "$repo_root/appsets"
replace_placeholders_in_tree "$repo_root/dev"
replace_placeholders_in_tree "$repo_root/prod"
replace_placeholders_in_tree "$repo_root/templates"
cleanup_initialization_artifacts

rm -f "$script_path"

echo "Repository initialized for $github_org/$repo_name"
echo "Updated placeholders for domain $base_domain"
echo "Removed template initialization docs and Makefile target"
echo "Removed $script_path"
