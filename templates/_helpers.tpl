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

{{- define "pupitre.api.labels" -}}
{{ include "pupitre.labels" . }}
app.kubernetes.io/component: api
{{- end }}

{{- define "pupitre.frontend.labels" -}}
{{ include "pupitre.labels" . }}
app.kubernetes.io/component: frontend
{{- end }}


{{/*
Selector labels
*/}}
{{- define "pupitre.api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/component: api
{{- end }}

{{- define "pupitre.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{- define "pupitre.postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupitre.name" . }}
app.kubernetes.io/component: postgresql
{{- end }}


{{/*
Name of a Secret the chart reads. The chart renders no Secret: they are
created by the user, or by External Secrets Operator (externalSecret.enabled).
A reference left empty falls back to existingSecret, then to <release>-secrets.
Takes (dict "root" $ "name" <the reference's own Secret name>).
*/}}
{{- define "pupitre.secretName" -}}
{{- .name | default .root.Values.existingSecret | default (printf "%s-secrets" (include "pupitre.fullname" .root)) -}}
{{- end }}

{{/*
Service account of a component: <release>-<component> when the chart creates
it, otherwise the one named in the values (the namespace's default if none).
Takes (dict "root" $ "component" "api" "serviceAccount" .Values.api.serviceAccount).
*/}}
{{- define "pupitre.serviceAccountName" -}}
{{- if .serviceAccount.create -}}
{{- .serviceAccount.name | default (printf "%s-%s" (include "pupitre.fullname" .root) .component) -}}
{{- else -}}
{{- .serviceAccount.name | default "default" -}}
{{- end -}}
{{- end }}

{{/*
Name of the PersistentVolumeClaim of the uploads.
*/}}
{{- define "pupitre.uploadsClaimName" -}}
{{- if .Values.api.uploads.persistence.existingClaim -}}
{{ .Values.api.uploads.persistence.existingClaim }}
{{- else -}}
{{ include "pupitre.fullname" . }}-uploads
{{- end -}}
{{- end }}

{{/*
The routing table, in one place.

Both the Ingress and the HTTPRoute render from this list, so the two cannot
drift apart.

genesary/pupitre-helm split /api between user-service and course-service by
prefix. pupitre-api serves every one of those routes, so /api is one prefix
again, with /uploads (the media), /metrics and /health. /metrics is routed
as in the reference; Prometheus may also scrape the pod (api.podAnnotations).

Every rule is a plain prefix (or one exact path), which is Gateway API *Core*
conformance and the common denominator of every Ingress controller.
*/}}
{{- define "pupitre.routeTable" -}}
routes:
  # ── api ────────────────────────────────────────────────────────────────────
  - path: /api
    match: prefix
    service: api
  - path: /uploads
    match: prefix
    service: api
  - path: /metrics
    match: prefix
    service: api
  - path: /health
    match: exact
    service: api

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
{{- if eq $svc "api" -}}{{ $root.Values.api.service.port }}
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
public URL it hands to CORS and the OAuth redirect base, nothing more.
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
Public base URL of the app (used for CORS and the OAuth redirect base)
*/}}
{{- define "pupitre.publicUrl" -}}
{{ include "pupitre.scheme" . }}://{{ include "pupitre.publicHost" . }}
{{- end }}

{{/*
Restrictive container security context. The API image runs as 1000:1000,
the frontend image (nginx-unprivileged) as 101:101.
Takes (dict "uid" <uid>).
*/}}
{{- define "pupitre.securityContext" -}}
runAsNonRoot: true
runAsUser: {{ .uid }}
runAsGroup: {{ .uid }}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: [ALL]
seccompProfile:
  type: RuntimeDefault
{{- end }}
