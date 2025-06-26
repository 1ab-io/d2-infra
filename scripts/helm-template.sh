#!/bin/bash

set -eux

# environment=staging

rm -fr manifests.out manifests

mkdir -p manifests.out manifests

# chart="${{ matrix.component }}"
for chart in cert-manager cilium external-secrets flux-operator talos-ccm; do
  # TODO: https://github.com/fluxcd/flux2/issues/2808
  # controller_ks="components/$chart/controllers/$environment/kustomization.yaml"
  # config_ks="components/$chart/configs/$environment/kustomization.yaml"
  repo_file="components/$chart/controllers/base/repository.yaml"
  file="components/$chart/controllers/base/release.yaml"
  ks="components/$chart/controllers/base/kustomization.yaml"
  ns="components/$chart/controllers/base/namespace.yaml"
  url=$(yq e '.spec.url' "$repo_file")
  version=$(yq e '.spec.ref.tag' "$repo_file")
  release_name=$(yq e '.spec.releaseName' "$file")
  namsespace=$(yq e '.namespace' "$ks")
  yq e '.spec.values' $file >"manifests.out/$chart.values.yaml"
  if [ "$version" = null ]; then
    version="*"
  fi
  if [[ "$url" == oci://* ]]; then
    helm pull "$url/$release_name" --version "$version" --untar --untardir manifests.out
  else
    helm repo add --force-update "$chart" "$url"
    helm repo update
    helm pull "$chart/$release_name" --version "$version" --untar --untardir manifests.out
  fi
  args=()
  if [ "$namsespace" != null ]; then
    args+=("--namespace=$namsespace")
  fi
  helm template "${args[@]}" "$release_name" "manifests.out/$release_name" --values "manifests.out/$chart.values.yaml" >"manifests.out/$chart.yaml"
  if [ -f "$ns" ]; then
    cat "$ns" >>"manifests/$chart.yaml"
  fi
  cat "manifests.out/$chart.yaml" >>"manifests/$chart.yaml"
done
