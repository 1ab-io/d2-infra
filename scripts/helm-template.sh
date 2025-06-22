#!/bin/bash

set -eux

# environment=staging

rm -fr manifests.out manifests

mkdir -p manifests.out manifests

# chart="${{ matrix.component }}"
for chart in cert-manager cilium external-secrets flux-operator talos-ccm; do
  # TODO: https://github.com/fluxcd/flux2/issues/2808
  # controller_ks="components/$chart/controllers/$environment/kustomization.yaml"
  repo_file="components/$chart/controllers/base/repository.yaml"
  file="components/$chart/controllers/base/release.yaml"
  ks="components/$chart/controllers/base/kustomization.yaml"
  ns="components/$chart/controllers/base/namespace.yaml"
  url=$(yq -r '.spec.url' "$repo_file")
  version=$(yq -r '.spec.ref.tag' "$repo_file")
  release_name=$(yq -r '.spec.releaseName' "$file")
  namsespace=$(yq -r '.namespace' "$ks")
  yq -r '.spec.values' $file >"manifests.out/$chart.values.yaml"
  if [ "$version" = null ]; then
    version="*"
  fi
  if [[ "$url" == oci://* ]]; then
    helm pull "$url" --version "$version" --untar --untardir manifests.out
  else
    helm repo add --force-update "$chart" "$url"
    helm repo update
    helm pull "$chart/$release_name" --version "$version" --untar --untardir manifests.out
  fi

  args=()
  if [ "$namsespace" != null ]; then
    args+=("--namespace=$namsespace")
  fi

  if [ -f "$ns" ]; then
    cat "$ns" >>"manifests/$chart.yaml"
  fi

  helm template "${args[@]}" "$release_name" "manifests.out/$release_name" --values "manifests.out/$chart.values.yaml" >>"manifests/$chart.yaml"

  environment=staging
  config_dir="components/$chart/configs/$environment"
  if [ -d "$config_dir" ]; then
    kustomize build "$config_dir" \
      --enable-alpha-plugins --enable-exec \
      >"manifests/$chart.config.yaml"
  fi
done
