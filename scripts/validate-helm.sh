#!/bin/bash

set -euo pipefail

validate_helm_release() {
    local file="$1"
    local chart_name
    chart_name=$(basename "$(dirname "$(dirname "$(dirname "$file")")")")

    echo "Validating Helm release: $file"

    # File paths
    local repo_file="components/$chart_name/controllers/base/repository.yaml"
    local ks="components/$chart_name/controllers/base/kustomization.yaml"

    if [[ ! -f "$repo_file" ]]; then
        echo "Warning: Repository file not found for $chart_name, skipping validation"
        return 0
    fi

    # Extract required values
    local url version release_name namespace
    url=$(yq -r '.spec.url' "$repo_file")
    version=$(yq -r '.spec.ref.tag' "$repo_file")
    release_name=$(yq -r '.spec.releaseName' "$file")
    namespace=$(yq -r '.namespace' "$ks")

    # Use wildcard if no version specified
    if [[ "$version" == "null" ]]; then
        version="*"
    fi

    # Check required fields
    if [[ "$url" == "null" || "$release_name" == "null" ]]; then
        echo "Error: Missing required fields in $file"
        return 1
    fi

    # Validate version format
    if [[ "$version" != "*" && ! "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format '$version' in $file"
        return 1
    fi

    # Create temporary directory for validation
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Extract values file
    yq -r '.spec.values' "$file" >"$temp_dir/$chart_name.values.yaml"

    # Download chart
    if [[ "$url" == oci://* ]]; then
        if ! helm pull "$url" --version "$version" --untar --untardir "$temp_dir" 2>/dev/null; then
            echo "Error: Failed to pull OCI chart $url:$version"
            return 1
        fi
    else
        local repo_name="$chart_name-temp"
        if ! helm repo add --force-update "$repo_name" "$url" >/dev/null 2>&1; then
            echo "Error: Failed to add Helm repository $url"
            return 1
        fi

        if ! helm repo update >/dev/null 2>&1; then
            echo "Error: Failed to update Helm repositories"
            return 1
        fi

        if ! helm pull "$repo_name/$release_name" --version "$version" --untar --untardir "$temp_dir" 2>/dev/null; then
            echo "Error: Failed to pull chart $repo_name/$release_name:$version"
            helm repo remove "$repo_name" >/dev/null || true
            return 1
        fi

        helm repo remove "$repo_name" >/dev/null || true
    fi

    # Build template arguments
    local args=()
    if [[ "$namespace" != "null" ]]; then
        args+=("--namespace=$namespace")
    fi

    # Validate chart template
    if ! helm template --dry-run --validate "${args[@]}" "$release_name" "$temp_dir/$release_name" --values "$temp_dir/$chart_name.values.yaml" >/dev/null; then
        echo "Error: Helm template validation failed for $file"
        return 1
    fi

    # Validate kustomize configs if they exist
    local config_dir="components/$chart_name/configs/staging"
    if [[ -d "$config_dir" ]]; then
        echo "  ✓ Config found, validating with kustomize"
        if ! kustomize build "$config_dir" --enable-alpha-plugins --enable-exec >/dev/null 2>&1; then
            echo "Error: Kustomize validation failed for $config_dir"
            return 1
        fi
    fi

    echo "✓ Validation passed for $file"
}

main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <helm-release-file> [<helm-release-file2> ...]"
        echo "   or: $0 --all  # validate all release files"
        exit 1
    fi

    if [[ "$1" == "--all" ]]; then
        while IFS= read -r -d '' file; do
            if ! validate_helm_release "$file"; then
                exit 1
            fi
        done < <(find components -name "release.yaml" -path "*/controllers/base/*" -print0)
    else
        for file in "$@"; do
            if [[ ! -f "$file" ]]; then
                echo "Error: File $file does not exist"
                exit 1
            fi
            if ! validate_helm_release "$file"; then
                exit 1
            fi
        done
    fi
}

main "$@"
