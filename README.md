# pupitre-helm

Helm chart for [pupitre](https://github.com/genesary/pupitre). It deploys three things:

- one API, `pupitre-api` (Go);
- the frontend, `pupitre-front`: nginx serving the learner app and the admin app;
- an optional bundled PostgreSQL.

The chart is adapted from [`genesary/pupitre-helm`](https://github.com/genesary/pupitre-helm)
at `48e9ecb`. That chart deploys the three services of `genesary/pupitre`: user-service,
course-service and checker-service. Since v3.0.0, pupitre runs them as one API with the same
routes, tables and rules, so this chart deploys one API where the reference deploys three.

```
.
├── Chart.yaml
├── values.yaml
├── templates/        # api/, frontend/, postgresql/, routing, optional ExternalSecret
└── tests/            # helm-unittest specs
```

## Install

The chart creates no Secret: create one first, named `<release>-secrets` by default. With
External Secrets Operator, `externalSecret` creates it from your store instead.

```bash
kubectl create secret generic pupitre-secrets \
  --from-literal=JWT_SECRET="$(openssl rand -hex 32)" \
  --from-literal=ADMIN_PASSWORD="$(openssl rand -hex 16)" \
  --from-literal=DATABASE_URL='postgres://pupitre:<password>@<host>:5432/pupitre'

helm install pupitre oci://ghcr.io/genesary/charts/pupitre --version <version>
```

Or from source:

```bash
helm install pupitre . -f my-values.yaml
```

The images default to the chart's `appVersion`, which is a release of pupitre. They are
`ghcr.io/genesary/pupitre-api` and `ghcr.io/genesary/pupitre-front`. Pin a version tag,
never `latest`.

`values.yaml` lists every setting: secrets, images, ingress, resources, uploads and SSO.

### What to set

| Value | Why |
| --- | --- |
| `ingress.host` (and `ingress.tls`) | The public URL. The CORS origin and the OAuth redirect base are built from it |
| `existingSecret` or `externalSecret` | The Secret holding `JWT_SECRET`, `DATABASE_URL` and `ADMIN_PASSWORD`, and the other keys listed in `values.yaml`. `JWT_SECRET` must be at least 32 characters: the API refuses shorter ones |
| `postgresql.enabled` | An external database (recommended) or the bundled one. `DATABASE_URL` points at either |
| `sso.oidc.*` | Keycloak sign-in. See the note on `groupAdmins` below |
| `api.uploads.persistence` | The media volume at `/data/uploads`, persistent by default |
| `api.resources`, `frontend.resources` | None by default; `values.yaml` recommends some |

The API is not tested with several replicas yet: the chart renders no HorizontalPodAutoscaler or
PodDisruptionBudget for it, and `api.replicaCount` stays at 1.

**`sso.oidc.groupAdmins`**: leave it empty when the platform has managers. When it is set, every
OIDC user outside those groups becomes a student at each sign-in, managers included. Map the admin
group in `/admin/groups` instead.

## Routing

The platform is one hostname in front of two backends:

```
/api, /uploads, /metrics, /health   → api
/                                   → frontend (the admin app answers /admin and /manager)
```

The routing table is defined once, in `pupitre.routeTable` (`templates/_helpers.tpl`). Both front
doors are rendered from it, so they cannot disagree about which backend owns a path.

Every rule is a prefix match, or one exact match. That is Gateway API *Core* conformance, which
every Ingress controller also supports.

`/metrics` is routed to the API and public, as in the reference chart. Prometheus can also scrape
the pod directly: add the `prometheus.io/*` annotations to `api.podAnnotations`.

### Choosing a front door

`ingress` and `httpRoute` are independent, and both **may be enabled at once**. That is useful
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

`httpRoute.hostnames` defaults to `[ ingress.host ]`. A single-host install therefore sets the
hostname in one place, whichever front door it uses.

## Upgrading from genesary/pupitre-helm

The API uses the three services' database **as it is**: same tables, same migrations. An existing
release can be upgraded in place.

### Values

| genesary/pupitre-helm | This chart |
| --- | --- |
| `userService.*`, `courseService.*`, `checkerService.*` | `api.*`: one block for the image, resources, env, extra volumes… |
| `jwtSecret`, `admin.password`, `courseService.gitToken`, `checkerService.gitLabToken`, `sso.oidc.clientSecret`, `sso.providers[].clientSecret`, `database.auth.password` | Removed: the values take no secret. Put them in the Secret (see "Switch-over") |
| `courseService.gitTokenExistingSecret*` | `api.gitTokenExistingSecret*` |
| `checkerService.env.GITLAB_BASE_URL` | `api.env.GITLAB_BASE_URL` |
| `internalServiceSecret*` | Removed: no internal route is left |
| `database.host`, `database.port`, `clusterDomain` | Removed: `DATABASE_URL` holds the connection |
| `userService.autoscaling`, `courseService.autoscaling` | Removed, with the API's PodDisruptionBudget: the API is not tested with several replicas |
| `api.resources`, `frontend.resources` | None by default |
| `frontend.image` (`pupitre-frontend`, Astro) | `frontend.image` (`pupitre-front`, nginx) |
| `admin.existingSecret*`, `sso.*`, `ingress.*`, `httpRoute.*`, `postgresql.*`, `networkPolicy.enabled` | Unchanged |

`DB_MAX_OPEN_CONNS` and `DB_MAX_IDLE_CONNS` default to 30, the sum of the two services' pools.
Changing the JWT secret signs every user out once.

### Switch-over

1. **Back up the database.**
2. **Copy the release Secret.** The reference chart owns `<release>-secrets`, so the upgrade
   deletes it. Copy its keys into a Secret of another name, then set `existingSecret` to it:

   ```bash
   kubectl get secret <release>-secrets -o go-template='{{range $k, $v := .data}}{{$k}}={{$v | base64decode}}{{"\n"}}{{end}}' > pupitre.env
   kubectl create secret generic <release>-credentials --from-env-file=pupitre.env
   rm pupitre.env
   ```

   `JWT_SECRET` must not be the reference chart's placeholder, which the API refuses: replace
   it with a random secret of at least 32 characters. With the bundled PostgreSQL, also add the
   `db_password` key.
3. This step applies only with the **bundled PostgreSQL and persistence enabled**. The reference
   chart puts its own version in the StatefulSet's `volumeClaimTemplates`, and Kubernetes does
   not let an upgrade change those. Delete the StatefulSet but keep its pod and its volume; the
   upgrade recreates it on the same volume:

   ```bash
   kubectl delete statefulset <release>-postgresql --cascade=orphan
   ```

4. Upgrade with the converted values:

   ```bash
   helm upgrade <release> oci://ghcr.io/genesary/charts/pupitre --version <version> -f my-values.yaml --wait
   ```

   Helm then does three things:
   - creates the API;
   - routes `/api` and `/uploads` to it;
   - removes the three services.

   Requests to `/api` fail for the few seconds the API takes to become ready.

5. Check the API, then check that sign-in works:

   ```bash
   kubectl rollout status deploy/<release>-api
   kubectl run curl --rm -it --restart=Never --image=curlimages/curl -- curl -s http://<release>-api:8080/health
   ```

6. Upload the media again. Media uploaded before the switch-over were written inside the old
   course-service container, because the reference chart mounted no volume there, and they are
   gone with it.

### Rollback

`helm rollback <release> <revision>` brings the three services back on the same database. With the
bundled PostgreSQL and persistence, run the `kubectl delete statefulset … --cascade=orphan` of
step 3 first, for the same reason.

The API adds one migration, which lets an IdP group be mapped to `manager`. At start-up, the
reference user-service puts back its rule that only allows `admin` and `student`. That fails while
a group is mapped to `manager`, so first delete those mappings in `/admin/groups`.

## Development

```bash
helm lint . --strict
helm unittest .
```

On tagged pushes, chart releases are packaged and pushed to GHCR (`oci://ghcr.io/<owner>/charts`);
see `.github/workflows/ci-helm.yaml`. As in the reference, the tag is the chart version, without
a `v` (`2.0.0`).
