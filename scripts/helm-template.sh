#!/bin/bash

set -eux

rm -fr charts public

mkdir -p charts public
echo '<h1>Manifests</h1>' >public/index.html
echo '<ul>' >>public/index.html

# chart="${{ matrix.component }}"
for chart in cert-manager cilium external-secrets talos-ccm; do
  repo_file="components/$chart/controllers/base/repository.yaml"
  file="components/$chart/controllers/base/release.yaml"
  ks="components/$chart/controllers/base/kustomization.yaml"
  ns="components/$chart/controllers/base/namespace.yaml"
  url=$(yq e '.spec.url' "$repo_file")
  version=$(yq e '.spec.ref.tag' "$repo_file")
  release_name=$(yq e '.spec.releaseName' "$file")
  namsespace=$(yq e '.namespace' "$ks")
  yq e '.spec.values' $file >"charts/$chart.values.yaml"
  if [ "$version" = null ]; then
    version="*"
  fi
  if [[ "$url" == oci://* ]]; then
    helm pull "$url/$release_name" --version "$version" --untar --untardir charts
  else
    helm repo add --force-update "$chart" "$url"
    helm repo update
    helm pull "$chart/$release_name" --version "$version" --untar --untardir charts
  fi
  args=()
  if [ "$namsespace" != null ]; then
    args+=("--namespace=$namsespace")
  fi
  helm template "${args[@]}" "$release_name" "charts/$release_name" --values "charts/$chart.values.yaml" >"charts/$chart.yaml"
  echo "# $chart $version" >"public/$chart.yaml"
  if [ -f "$ns" ]; then
    cat "$ns" >>"public/$chart.yaml"
  fi
  cat "charts/$chart.yaml" >>"public/$chart.yaml"
  echo '<li><a href="'$chart'.yaml">'$chart'</a></li>' >>public/index.html
done
echo '</ul>' >>public/index.html
