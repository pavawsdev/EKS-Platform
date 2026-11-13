{{/*
Two naming patterns coexist across the services this chart serves:
- backend/frontend: fullname is Release.Name-derived ("<release>-<component>"),
  since each gets its own ArgoCD Application/release per environment.
- vulntracker/vulntracker-notify: fullname is FIXED (ignores Release.Name)
  because they call each other over a hardcoded in-cluster Service DNS name
  (see values.yaml's env.NOTIFY_SERVICE_URL/PYTHON_API_URL) - that only stays
  predictable if the Service name doesn't depend on whatever release name
  ArgoCD happens to assign. Safe since each is deployed exactly once per
  environment/namespace. Set `nameOverride` to opt into the fixed pattern.
*/}}
{{- define "application.fullname" -}}
{{- if .Values.nameOverride -}}
{{ .Values.nameOverride }}
{{- else -}}
{{ .Release.Name }}-{{ .Values.tags.component }}
{{- end -}}
{{- end -}}

{{- define "application.labels" -}}
app.kubernetes.io/name: {{ .Values.tags.component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Values.tags.project }}
app.kubernetes.io/environment: {{ .Values.environment }}
{{- end -}}

{{- define "application.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.tags.component }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
