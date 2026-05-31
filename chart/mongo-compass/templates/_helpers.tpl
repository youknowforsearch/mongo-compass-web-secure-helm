{{/*
Expand the name of the chart.
*/}}
{{- define "mongo-compass.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mongo-compass.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mongo-compass.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mongo-compass.labels" -}}
helm.sh/chart: {{ include "mongo-compass.chart" . }}
{{ include "mongo-compass.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mongo-compass.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mongo-compass.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mongo-compass.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mongo-compass.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
OAuth2 Proxy secret name
*/}}
{{- define "mongo-compass.oauth2ProxySecretName" -}}
{{- if .Values.oauth2Proxy.existingSecret }}
{{- .Values.oauth2Proxy.existingSecret }}
{{- else }}
{{- printf "%s-oauth2-proxy" (include "mongo-compass.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Public hostname from HTTPRoute or Ingress
*/}}
{{- define "mongo-compass.publicHostname" -}}
{{- if and .Values.httpRoute.enabled (gt (len .Values.httpRoute.hostnames) 0) }}
{{- index .Values.httpRoute.hostnames 0 }}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) }}
{{- (index .Values.ingress.hosts 0).host }}
{{- end }}
{{- end }}

{{/*
Public URL scheme for OAuth callback derivation
*/}}
{{- define "mongo-compass.publicScheme" -}}
{{- if .Values.httpRoute.enabled }}
{{- default "https" .Values.httpRoute.scheme }}
{{- else if and .Values.ingress.enabled (gt (len .Values.ingress.tls) 0) }}
https
{{- else }}
http
{{- end }}
{{- end }}

{{/*
OAuth2 Proxy redirect URL for Keycloak callback
*/}}
{{- define "mongo-compass.oauth2ProxyRedirectURL" -}}
{{- if .Values.oauth2Proxy.redirectURL }}
{{- .Values.oauth2Proxy.redirectURL }}
{{- else if include "mongo-compass.publicHostname" . }}
{{- printf "%s://%s/oauth2/callback" (include "mongo-compass.publicScheme" .) (include "mongo-compass.publicHostname" .) }}
{{- else }}
{{- fail "oauth2Proxy.redirectURL must be set when oauth2Proxy is enabled and neither httpRoute nor ingress provides a hostname" }}
{{- end }}
{{- end }}

{{/*
External service port (oauth2-proxy when auth is enabled)
*/}}
{{- define "mongo-compass.servicePort" -}}
{{- if .Values.oauth2Proxy.enabled }}
{{- .Values.oauth2Proxy.port }}
{{- else }}
{{- .Values.service.port }}
{{- end }}
{{- end }}
