{{- define "frontend.fullname" -}}
{{ .Release.Name }}-frontend
{{- end -}}

{{- define "frontend.labels" -}}
app.kubernetes.io/name: frontend
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Values.tags.project }}
app.kubernetes.io/environment: {{ .Values.environment }}
{{- end -}}

{{- define "frontend.selectorLabels" -}}
app.kubernetes.io/name: frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
