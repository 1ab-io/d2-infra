# d2-infra

> [!NOTE]
> This repository is part of the reference architecture for the
> [ControlPlane Enterprise for Flux CD](https://fluxcd.control-plane.io/).
>
> The `d2` reference architecture comprised of
> [d2-fleet](https://github.com/controlplaneio-fluxcd/d2-fleet),
> [d2-infra](https://github.com/controlplaneio-fluxcd/d2-infra) and
> [d2-apps](https://github.com/controlplaneio-fluxcd/d2-apps)
> is a set of best practices and production-ready examples for using Flux Operator
> and OCI Artifacts to manage the continuous delivery of Kubernetes infrastructure and
> applications on multi-cluster multi-tenant environments.
>
> Download the guide: [Flux D2 Architectural Reference](https://raw.githubusercontent.com/controlplaneio-fluxcd/distribution/main/guides/ControlPlane_Flux_D2_Reference_Architecture_Guide.pdf)

## Scope and Access Control

This repository is managed by the platform team who are responsible for
the Kubernetes infrastructure.

This repository is used to define the Kubernetes infrastructure components such as:

- Cluster add-ons (CRD controllers, admission controllers, monitoring, logging, etc.)
- Cluster-wide definitions (Namespaces, Ingress classes, Storage classes, etc.)
- Pod security standards
- Network policies

This repository is reconciled on the cluster fleet by Flux as the **cluster admin**.
Access to this repository is restricted to the platform team.

## Repository Structure

This repository contains the following directories:

- The **components** dir contains Flux HelmReleases for cluster addons with custom
  configuration per environment.
- The **update-polices** dir contains the Flux configuration for automating the OCI chart updates
  of the Helm releases.

A cluster component is defined in a directory with the following structure:

```sh
component/
├── controllers # CRD definitions and controllers
│   ├── base # common definitions (Namespaces, RBAC, HelmRepositories, HelmReleases)
│   ├── production # production specific HelmRelease values
│   └── staging # staging specific HelmRelease values
└── configs # Custom Resources of controllers
    ├── base # common definitions
    ├── production # production specific values
    └── staging # staging specific values
```

The CRDs and their controllers are reconciled before the custom resources to ensure that the
controllers are ready to process the custom resources.
