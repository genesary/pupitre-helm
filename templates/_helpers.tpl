{{/*
Expand the name of the chart.
*/}}
{{- define "pupitre.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pupitre.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pupitre.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "pupitre.courseService.labels" -}}
{{ include "pupitre.labels" . }}
app.kubernetes.io/component: course-service
{{- end }}

{{- define "pupitre.userService.labels" -}}
{{ include "pupitre.labels" . }}
app.kubernetes.io/component: user-service
{{- end }}

{{- define "pupitre.frontend.labels" -}}
{{ include "pupitre.labels" . }}
app.kubernetes.io/component: frontend
{{- end }}


{{/*
Selector labels
*/}}
{{- define "pupitre.courseService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/component: course-service
{{- end }}

{{- define "pupitre.userService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/component: user-service
{{- end }}

{{- define "pupitre.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{- define "pupitre.checkerService.labels" -}}
{{ include "pupitre.labels" . }}
app.kubernetes.io/component: checker-service
{{- end }}

{{- define "pupitre.checkerService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/component: checker-service
{{- end }}


{{/*
Admin password resolution — priority order:
  1. admin.existingSecret → caller manages the Secret entirely, we do nothing.
  2. admin.password non-empty → use the explicit value from values.yaml.
  3. Secret already exists (upgrade) → reuse ADMIN_PASSWORD from the live Secret
     so we never rotate a previously auto-generated password unintentionally.
  4. First install with no value → generate a cryptographically random 32-char
     alphanumeric password and store it in our platform Secret.
*/}}
{{- define "pupitre.adminPassword" -}}
{{- if not .Values.admin.existingSecret -}}
  {{- if .Values.admin.password -}}
    {{- .Values.admin.password -}}
  {{- else -}}
    {{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-secrets" (include "pupitre.fullname" .)) -}}
    {{- if and $secret $secret.data (index $secret.data "ADMIN_PASSWORD") -}}
      {{- index $secret.data "ADMIN_PASSWORD" | b64dec -}}
    {{- else -}}
      {{- randAlphaNum 32 -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Whether DATABASE_URL is supplied verbatim by a caller-managed Secret.
True only for an external database whose existingSecret exposes a full URL key.
*/}}
{{- define "pupitre.databaseUrlFromExternalSecret" -}}
{{- if and (not .Values.postgresql.enabled) .Values.database.auth.existingSecret .Values.database.auth.urlKey -}}
true
{{- end -}}
{{- end }}

{{/*
DATABASE_URL connection string, assembled from the `database` block.
Bundled PostgreSQL → in-cluster Service; otherwise → database.host/port.
*/}}
{{- define "pupitre.databaseUrl" -}}
{{- if .Values.postgresql.enabled -}}
postgres://{{ .Values.database.auth.username }}:{{ .Values.database.auth.password }}@{{ include "pupitre.fullname" . }}-postgresql.{{ .Release.Namespace }}.svc.{{ .Values.clusterDomain }}:5432/{{ .Values.database.name }}
{{- else -}}
postgres://{{ .Values.database.auth.username }}:{{ .Values.database.auth.password }}@{{ .Values.database.host }}:{{ .Values.database.port }}/{{ .Values.database.name }}
{{- end -}}
{{- end }}

{{/*
Name of the Secret that holds DATABASE_URL.
When the external database exposes its own URL Secret, point directly to it;
otherwise the chart renders DATABASE_URL into its own Secret.
*/}}
{{- define "pupitre.databaseUrlSecretName" -}}
{{- if eq (include "pupitre.databaseUrlFromExternalSecret" .) "true" -}}
{{ .Values.database.auth.existingSecret }}
{{- else -}}
{{ include "pupitre.fullname" . }}-secrets
{{- end -}}
{{- end }}

{{- define "pupitre.databaseUrlSecretKey" -}}
{{- if eq (include "pupitre.databaseUrlFromExternalSecret" .) "true" -}}
{{ .Values.database.auth.urlKey }}
{{- else -}}
DATABASE_URL
{{- end -}}
{{- end }}

{{/*
Name of the Secret that holds GIT_TOKEN.
*/}}
{{- define "pupitre.gitTokenSecretName" -}}
{{- if .Values.courseService.gitTokenExistingSecret -}}
{{ .Values.courseService.gitTokenExistingSecret }}
{{- else -}}
{{ include "pupitre.fullname" . }}-secrets
{{- end -}}
{{- end }}

{{- define "pupitre.gitTokenSecretKey" -}}
{{- if .Values.courseService.gitTokenExistingSecret -}}
{{ .Values.courseService.gitTokenExistingSecretKey }}
{{- else -}}
GIT_TOKEN
{{- end -}}
{{- end }}

{{/*
Whether GIT_TOKEN should be injected as an env var (true when a token is configured).
*/}}
{{- define "pupitre.gitTokenEnabled" -}}
{{- if or .Values.courseService.gitToken .Values.courseService.gitTokenExistingSecret -}}
true
{{- end -}}
{{- end }}

{{/*
Name of the Secret that holds JWT_SECRET.
*/}}
{{- define "pupitre.jwtSecretName" -}}
{{- if .Values.jwtExistingSecret -}}
{{ .Values.jwtExistingSecret }}
{{- else -}}
{{ include "pupitre.fullname" . }}-secrets
{{- end -}}
{{- end }}

{{- define "pupitre.jwtSecretKey" -}}
{{- if .Values.jwtExistingSecret -}}
{{ .Values.jwtExistingSecretKey }}
{{- else -}}
JWT_SECRET
{{- end -}}
{{- end }}

{{- define "pupitre.internalSecretName" -}}
{{- if .Values.internalServiceExistingSecret -}}
{{ .Values.internalServiceExistingSecret }}
{{- else -}}
{{ include "pupitre.fullname" . }}-secrets
{{- end -}}
{{- end }}

{{- define "pupitre.internalSecretKey" -}}
{{- if .Values.internalServiceExistingSecret -}}
{{ .Values.internalServiceExistingSecretKey }}
{{- else -}}
INTERNAL_SERVICE_SECRET
{{- end -}}
{{- end }}

{{/*
The routing table, in one place.

Both the Ingress and the HTTPRoute render from this list, so the two cannot
drift apart — which is how /api/paths, /api/skills, /api/admin/cache and
/api/admin/exports/lab-checks previously ended up unrouted or pointed at the
wrong service while the dev proxy in the frontend routed them correctly.

Every rule is a plain prefix (or one exact path), which is Gateway API *Core*
conformance and the common denominator of every Ingress controller. That is
deliberate: no service registers a route inside another's prefix, so nothing
here needs a regex.

It did once. A handful of user-service endpoints sat under course-service
prefixes with a course slug in the middle — POST /api/courses/{slug}/enroll,
GET /api/admin/courses/{slug}/enrollments — where the owner is only decided
*after* a variable segment, which no prefix match can express. Each front door
then needed its own workaround: a Traefik-only IngressRoute CRD, an nginx
regex annotation, and an implementation-specific Gateway API match. Those
endpoints were moved to resources of their own (/api/enrollments,
/api/session-bookings), so the whole table is portable again.

Keep it that way: an endpoint whose owner depends on a segment after a
wildcard reintroduces the coupling to what the ingress happens to support.
*/}}
{{- define "pupitre.routeTable" -}}
routes:
  # ── course-service ─────────────────────────────────────────────────────────
  - path: /api/admin/exports/lab-checks
    match: prefix
    service: course-service
  - path: /api/admin/courses
    match: prefix
    service: course-service
  - path: /api/admin/lab-checks
    match: prefix
    service: course-service
  - path: /api/admin/cache
    match: prefix
    service: course-service
  - path: /api/courses
    match: prefix
    service: course-service
  - path: /api/paths
    match: prefix
    service: course-service
  - path: /api/skills
    match: prefix
    service: course-service
  # Server-to-server batch lookups; kept off /api/courses and /api/paths so no
  # course or path slug can shadow them.
  - path: /api/batch
    match: prefix
    service: course-service
  - path: /uploads
    match: prefix
    service: course-service
  - path: /metrics
    match: prefix
    service: course-service
  - path: /health
    match: exact
    service: course-service

  # ── user-service ───────────────────────────────────────────────────────────
  # Enrolling and session booking are keyed by course slug but owned by
  # user-service, so they are their own resources rather than verbs hung off
  # the catalog's URLs — see the note above.
  - path: /api/admin/session-bookings
    match: prefix
    service: user-service
  - path: /api/admin/enrollments
    match: prefix
    service: user-service
  - path: /api/manager/session-bookings
    match: prefix
    service: user-service
  - path: /api/manager/enrollments
    match: prefix
    service: user-service
  - path: /api/session-bookings
    match: prefix
    service: user-service
  - path: /api/enrollments
    match: prefix
    service: user-service
  - path: /api/leaderboard
    match: prefix
    service: user-service
  - path: /api/patterns
    match: prefix
    service: user-service
  - path: /api/settings
    match: prefix
    service: user-service
  - path: /api/manager
    match: prefix
    service: user-service
  - path: /api/badges
    match: prefix
    service: user-service
  - path: /api/users
    match: prefix
    service: user-service
  - path: /api/admin
    match: prefix
    service: user-service
  - path: /api/auth
    match: prefix
    service: user-service
  - path: /api/my
    match: prefix
    service: user-service

  # ── frontend (catch-all) ───────────────────────────────────────────────────
  - path: /
    match: prefix
    service: frontend
{{- end }}

{{/*
Numeric Service port for a route's target, which HTTPRoute backendRefs
require (an Ingress may use the port name, a Gateway API route may not).
*/}}
{{- define "pupitre.routeServicePort" -}}
{{- $svc := .service -}}
{{- $root := .root -}}
{{- if eq $svc "course-service" -}}{{ $root.Values.courseService.service.port }}
{{- else if eq $svc "user-service" -}}{{ $root.Values.userService.service.port }}
{{- else -}}{{ $root.Values.frontend.service.port }}
{{- end -}}
{{- end }}

{{/*
Hostnames an HTTPRoute attaches to: httpRoute.hostnames when set, otherwise
the Ingress host, so a single-host deployment configures it in one place.
*/}}
{{- define "pupitre.httpRouteHostnames" -}}
{{- if .Values.httpRoute.hostnames -}}
{{ toYaml .Values.httpRoute.hostnames }}
{{- else if .Values.ingress.host -}}
- {{ .Values.ingress.host | quote }}
{{- end -}}
{{- end }}

{{/*
Public scheme (http or https).

TLS is terminated at the Ingress when `ingress.tls` is set, and at the Gateway
listener — which this chart does not own — when the HTTPRoute is used. The
latter is why `httpRoute.tls` exists: it tells the chart how to spell the
public URL it hands to CORS and ORIGIN, nothing more.
*/}}
{{- define "pupitre.scheme" -}}
{{- if or .Values.ingress.tls .Values.httpRoute.tls }}https{{- else }}http{{- end }}
{{- end }}

{{/*
Public host of the app. The HTTPRoute's first hostname when it overrides the
Ingress host, otherwise the Ingress host.
*/}}
{{- define "pupitre.publicHost" -}}
{{- if and .Values.httpRoute.enabled .Values.httpRoute.hostnames -}}
{{ first .Values.httpRoute.hostnames }}
{{- else -}}
{{ .Values.ingress.host }}
{{- end -}}
{{- end }}

{{/*
Public base URL of the app (used for CORS, ORIGIN)
*/}}
{{- define "pupitre.publicUrl" -}}
{{ include "pupitre.scheme" . }}://{{ include "pupitre.publicHost" . }}
{{- end }}

{{/*
Default container security context — restrictive, suitable for all services.
Override per-container in values if a service needs specific capabilities.
*/}}
{{- define "pupitre.securityContext" -}}
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: [ALL]
{{- end }}
