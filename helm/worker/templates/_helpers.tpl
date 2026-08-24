{{- define "worker.fullname" -}}
{{ .Release.Name }}-worker
{{- end -}}

{{- define "worker.labels" -}}
app.kubernetes.io/name: worker
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Values.tags.project }}
app.kubernetes.io/environment: {{ .Values.environment }}
{{- end -}}

{{- define "worker.selectorLabels" -}}
app.kubernetes.io/name: worker
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
