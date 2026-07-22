{{- define "backend.fullname" -}}
{{ .Release.Name }}-backend
{{- end -}}

{{- define "backend.labels" -}}
app.kubernetes.io/name: backend
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Values.tags.project }}
app.kubernetes.io/environment: {{ .Values.environment }}
{{- end -}}

{{- define "backend.selectorLabels" -}}
app.kubernetes.io/name: backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
