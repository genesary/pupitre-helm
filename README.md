# pupitre-helm

Helm chart for the [Pupitre](https://github.com/genesary/pupitre) eLearning Platform — Course Service (Go) + User Service (Go) + Checker Service (Go) + Frontend (Astro) + PostgreSQL.

```
.
├── Chart.yaml
├── values.yaml
├── crds/            # Course, MarkdownPattern, Path CRDs
├── templates/        # Per-service manifests, ingress, secrets
└── tests/             # helm-unittest specs
```

## Install

```bash
helm install pupitre oci://ghcr.io/<owner>/charts/elearning --version <version>
```

Or from source:

```bash
helm install pupitre . -f my-values.yaml
```

The chart uses Bitnami PostgreSQL by default (`postgresql.enabled: true`). On resource-constrained clusters (e.g. local KinD), this may get stuck `Pending` due to insufficient ephemeral storage — set `postgresql.enabled: false` and point the services at an external database instead.

See `values.yaml` for the full list of configurable values (secrets, image overrides, ingress, per-service resources).

## Development

```bash
helm lint . --strict
helm unittest .
```

Chart releases are packaged and pushed to GHCR (`oci://ghcr.io/<owner>/charts`) on tagged pushes — see `.github/workflows/ci-helm.yaml`.
