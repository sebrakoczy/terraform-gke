{{- define "reference-app.name" -}}reference-app{{- end -}}
{{- define "reference-app.labels" -}}
app.kubernetes.io/name: {{ include "reference-app.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
