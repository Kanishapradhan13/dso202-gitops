{{/* charts/tasktracker/templates/_helpers.tpl - DSO202 A4 - naming and label helpers */}}
{{- define "tt.fullname" -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "tt.labels" -}}
app.kubernetes.io/name: tasktracker
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
environment: {{ .Values.environment }}
{{- end -}}
{{- define "tt.selector" -}}
app.kubernetes.io/name: tasktracker
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .tier }}
{{- end -}}
