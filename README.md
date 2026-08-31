# pupitre-helm

Helm chart for the [Pupitre](https://github.com/genesary/pupitre) eLearning Platform — Course Service (Go) + User Service (Go) + Checker Service (Go) + Frontend (Astro) + PostgreSQL.

```
.
├── Chart.yaml
├── values.yaml
├── templates/        # Per-service manifests, ingress, secrets
└── tests/             # helm-unittest specs
```

## Install

```bash
helm install pupitre oci://ghcr.io/<owner>/charts/pupitre --version <version>
```

Or from source:

```bash
helm install pupitre . -f my-values.yaml
```

The chart uses Bitnami PostgreSQL by default (`postgresql.enabled: true`). On resource-constrained clusters (e.g. local KinD), this may get stuck `Pending` due to insufficient ephemeral storage — set `postgresql.enabled: false` and point the services at an external database instead.

See `values.yaml` for the full list of configurable values (secrets, image overrides, ingress, per-service resources).

## Routing

The platform is one hostname in front of three backends. The split is a plain
prefix split, and deliberately so:

```
/api/courses, /api/paths, /api/skills, /api/batch,
/api/admin/courses, /api/admin/lab-checks,
/api/admin/cache, /api/admin/exports/lab-checks,
/uploads, /health, /metrics                          → course-service
/api/auth, /api/my, /api/settings, /api/manager,
/api/users, /api/badges, /api/leaderboard,
/api/patterns, /api/enrollments, /api/session-bookings,
/api/admin/*                                          → user-service
/                                                     → frontend
```

The table lives once in `pupitre.routeTable` (`templates/_helpers.tpl`); both
front doors render from it, so they cannot disagree about who owns a path.

**Every rule is a prefix (or one exact) match.** That is Gateway API *Core*
conformance and the common denominator of every Ingress controller, so the
chart routes correctly anywhere without controller-specific matching.

It was not always so. A few user-service endpoints used to sit *inside*
course-service prefixes with a course slug in the middle — `POST
/api/courses/{slug}/enroll`, `GET /api/admin/courses/{slug}/enrollments` —
where the owner is only decided after a variable segment, which no prefix
match can express. Each front door needed its own workaround: a Traefik-only
`IngressRoute` CRD, an nginx `use-regex` annotation, and an
implementation-specific Gateway API `RegularExpression` match. Those endpoints
were moved to resources of their own (`/api/enrollments`,
`/api/session-bookings`), and all three workarounds went away with them.

> Keep it that way. An endpoint whose owning service depends on a segment
> *after* a wildcard re-couples the platform to whatever its ingress happens
> to support. `TestRouter_NoCourseServicePrefixOverlap` in user-service fails
> if one is added.

### Choosing a front door

`ingress` and `httpRoute` are independent and **may both be enabled** — useful
while migrating, or to serve two entry points.

```yaml
ingress:
  enabled: true
  className: nginx      # or traefik, or any other; the rules are the same
  host: courses.example.com

httpRoute:
  enabled: true
  tls: true             # the Gateway listener terminates TLS
  parentRefs:
    - name: pupitre-gateway
      namespace: gateway-system
      sectionName: websecure
```

`httpRoute.hostnames` defaults to `[ ingress.host ]`, so a single-host install
sets the hostname in one place regardless of which front door is used.

## Development

```bash
helm lint . --strict
helm unittest .
```

Chart releases are packaged and pushed to GHCR (`oci://ghcr.io/<owner>/charts`) on tagged pushes — see `.github/workflows/ci-helm.yaml`.
