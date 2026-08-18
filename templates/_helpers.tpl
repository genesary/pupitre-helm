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
User-service paths that share the /api/courses and /api/admin/courses prefixes
with course-service. Injected into the main Ingress as ImplementationSpecific
(regex) entries when className is nginx — nginx evaluates regex locations before
plain prefix locations, so these win without any priority annotation.
*/}}
{{- define "pupitre.ingressNginxOverridePaths" -}}
- path: /api/courses/[^/]+/(enroll|unenroll)$
  pathType: ImplementationSpecific
  backend:
    service:
      name: {{ include "pupitre.fullname" . }}-user-service
      port:
        name: http
- path: /api/courses/[^/]+/sessions/
  pathType: ImplementationSpecific
  backend:
    service:
      name: {{ include "pupitre.fullname" . }}-user-service
      port:
        name: http
- path: /api/admin/courses/[^/]+/enrollments
  pathType: ImplementationSpecific
  backend:
    service:
      name: {{ include "pupitre.fullname" . }}-user-service
      port:
        name: http
- path: /api/admin/courses/[^/]+/sessions/[^/]+/bookings
  pathType: ImplementationSpecific
  backend:
    service:
      name: {{ include "pupitre.fullname" . }}-user-service
      port:
        name: http
{{- end }}

{{/*
Ingress scheme (http or https)
*/}}
{{- define "pupitre.scheme" -}}
{{- if .Values.ingress.tls }}https{{- else }}http{{- end }}
{{- end }}

{{/*
Public base URL of the app (used for CORS, ORIGIN)
*/}}
{{- define "pupitre.publicUrl" -}}
{{ include "pupitre.scheme" . }}://{{ .Values.ingress.host }}
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
