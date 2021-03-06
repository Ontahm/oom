{{/*#
# Copyright © 2020-2021, Nokia
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.*/}}

{{/*
# This is a template for requesting a certificate from the cert-manager (https://cert-manager.io).
#
# To request a certificate following steps are to be done:
#  - create an object 'certificates' in the values.yaml
#  - create a file templates/certificates.yaml and invoke the function "certManagerCertificate.certificate".
#
# Here is an example of the certificate request for a component:
#
# Directory structure:
#   component
#     templates
#       certifictes.yaml
#     values.yaml
#
# To be added in the file certificates.yamll
#
# To be added in the file values.yaml
#  1. Minimal version (certificates only in PEM format)
#  certificates:
#    - commonName: component.onap.org
#
#  2. Extended version (with defined own issuer and additional certificate format):
#  certificates:
#    - name:       onap-component-certificate
#      secretName: onap-component-certificate
#      commonName: component.onap.org
#      dnsNames:
#        - component.onap.org
#      issuer:
#        group: certmanager.onap.org
#        kind: CMPv2Issuer
#        name: cmpv2-issuer-for-the-component
#      keystore:
#        outputType:
#          - p12
#          - jks
#        passwordSecretRef:
#          name: secret-name
#          key:  secret-key
#
# Fields 'name', 'secretName' and 'commonName' are mandatory and required to be defined.
# Other mandatory fields for the certificate definition do not have to be defined directly,
# in that case they will be taken from default values.
#
# Default values are defined in file onap/values.yaml (see-> global.certificate.default)
# and can be overriden during onap installation process.
#
*/}}

{{- define "certManagerCertificate.certificate" -}}
{{- $dot := default . .dot -}}
{{- $initRoot := default $dot.Values.certManagerCertificate .initRoot -}}

{{- $certificates := $dot.Values.certificates -}}
{{- $subchartGlobal := mergeOverwrite (deepCopy $initRoot.global) $dot.Values.global }}

{{ range $i, $certificate := $certificates }}
{{/*# General certifiacate attributes  #*/}}
{{- $name           := include "common.fullname" $dot                                                             -}}
{{- $certName       := default (printf "%s-cert-%d"   $name $i) $certificate.name                                 -}}
{{- $secretName     := default (printf "%s-secret-%d" $name $i) $certificate.secretName                           -}}
{{- $commonName     := (required "'commonName' for Certificate is required." $certificate.commonName)          -}}
{{- $renewBefore    := default $subchartGlobal.certificate.default.renewBefore     $certificate.renewBefore    -}}
{{- $duration       := default $subchartGlobal.certificate.default.duration        $certificate.duration       -}}
{{- $namespace      := $dot.Release.Namespace      -}}
{{/*# SAN's #*/}}
{{- $dnsNames       := $certificate.dnsNames       -}}
{{- $ipAddresses    := $certificate.ipAddresses    -}}
{{- $uris           := $certificate.uris           -}}
{{- $emailAddresses := $certificate.emailAddresses -}}
{{/*# Subject #*/}}
{{- $subject        := $subchartGlobal.certificate.default.subject                                             -}}
{{- if $certificate.subject -}}
{{-   $subject       = $certificate.subject                                              -}}
{{- end -}}
{{/*# Issuer #*/}}
{{- $issuer         := $subchartGlobal.certificate.default.issuer                                              -}}
{{- if $certificate.issuer -}}
{{-   $issuer        = $certificate.issuer                                               -}}
{{- end -}}
---
{{- if $certificate.keystore }}
  {{- $passwordSecretRef := $certificate.keystore.passwordSecretRef -}}
  {{- $password := include "common.createPassword" (dict "dot" $dot "uid" $certName) | quote }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ $passwordSecretRef.name }}
  namespace: {{ $namespace }}
type: Opaque
stringData:
  {{ $passwordSecretRef.key }}: {{ $password }}
{{- end }}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name:        {{ $certName }}
  namespace:   {{ $namespace }}
spec:
  secretName:  {{ $secretName }}
  commonName:  {{ $commonName }}
  renewBefore: {{ $renewBefore }}
  {{- if $duration }}
  duration:    {{ $duration }}
  {{- end }}
  subject:
    organizations:
      - {{ $subject.organization }}
    countries:
      - {{ $subject.country }}
    localities:
      - {{ $subject.locality }}
    provinces:
      - {{ $subject.province }}
    organizationalUnits:
      - {{ $subject.organizationalUnit }}
  {{- if $dnsNames }}
  dnsNames:
    {{- range $dnsName := $dnsNames }}
      - {{ $dnsName }}
    {{- end }}
  {{- end }}
  {{- if $ipAddresses }}
  ipAddresses:
    {{- range $ipAddress := $ipAddresses }}
      - {{ $ipAddress }}
    {{- end }}
  {{- end }}
  {{- if $uris }}
  uris:
    {{- range $uri := $uris }}
      - {{ $uri }}
    {{- end }}
  {{- end }}
  {{- if $emailAddresses }}
  emailAddresses:
    {{- range $emailAddress := $emailAddresses }}
      - {{ $emailAddress }}
    {{- end }}
  {{- end }}
  issuerRef:
    group: {{ $issuer.group }}
    kind:  {{ $issuer.kind }}
    name:  {{ $issuer.name }}
  {{- if $certificate.keystore }}
  keystores:
    {{- range $outputType := $certificate.keystore.outputType }}
      {{- if eq $outputType "p12" }}
        {{- $outputType = "pkcs12" }}
      {{- end }}
    {{ $outputType }}:
      create: true
      passwordSecretRef:
        name: {{ $certificate.keystore.passwordSecretRef.name }}
        key: {{ $certificate.keystore.passwordSecretRef.key }}
    {{- end }}
  {{- end }}
{{ end }}
{{- end -}}

{{- define "common.certManager.volumeMounts" -}}
{{- $dot := default . .dot -}}
{{- $initRoot := default $dot.Values.certManagerCertificate .initRoot -}}
{{- $subchartGlobal := mergeOverwrite (deepCopy $initRoot.global) $dot.Values.global -}}
  {{- range $i, $certificate := $dot.Values.certificates -}}
    {{- $mountPath := $certificate.mountPath -}}
- mountPath: {{ (printf "%s/secret-%d" $mountPath $i) }}
  name: certmanager-certs-volume-{{ $i }}
- mountPath: {{ $mountPath }}
  name: certmanager-certs-volume-{{ $i }}-dir
   {{- end -}}
{{- end -}}

{{- define "common.certManager.volumes" -}}
{{- $dot := default . .dot -}}
{{- $initRoot := default $dot.Values.certManagerCertificate .initRoot -}}
{{- $subchartGlobal := mergeOverwrite (deepCopy $initRoot.global) $dot.Values.global -}}
{{- $certificates := $dot.Values.certificates -}}
  {{- range $i, $certificate := $certificates -}}
    {{- $name := include "common.fullname" $dot -}}
    {{- $certificatesSecretName := default (printf "%s-secret-%d" $name $i) $certificate.secretName -}}
- name: certmanager-certs-volume-{{ $i }}-dir
  emptyDir: {}
- name: certmanager-certs-volume-{{ $i }}
  projected:
    sources:
    - secret:
        name: {{ $certificatesSecretName }}
    {{- if $certificate.keystore }}
        items:
        {{- range $outputType := $certificate.keystore.outputType }}
          - key: keystore.{{ $outputType }}
            path: keystore.{{ $outputType }}
          - key: truststore.{{ $outputType }}
            path: truststore.{{ $outputType }}
        {{- end }}
    - secret:
        name: {{ $certificate.keystore.passwordSecretRef.name }}
        items:
          - key: {{ $certificate.keystore.passwordSecretRef.key }}
            path: keystore.pass
          - key: {{ $certificate.keystore.passwordSecretRef.key }}
            path: truststore.pass
     {{- end }}
  {{- end -}}
{{- end -}}

{{- define "common.certManager.linkVolumeMounts" -}}
{{- $dot := default . .dot -}}
{{- $initRoot := default $dot.Values.certManagerCertificate .initRoot -}}
{{- $subchartGlobal := mergeOverwrite (deepCopy $initRoot.global) $dot.Values.global -}}
{{- $certificates := $dot.Values.certificates -}}
{{- $certsLinkCommand := "" -}}
  {{- range $i, $certificate := $certificates -}}
    {{- $destnationPath := (required "'mountPath' for Certificate is required." $certificate.mountPath) -}}
    {{- $sourcePath := (printf "%s/secret-%d/*" $destnationPath $i) -}}
    {{- $certsLinkCommand = (printf "ln -s %s %s; %s" $sourcePath $destnationPath $certsLinkCommand) -}}
  {{- end -}}
{{ $certsLinkCommand }}
{{- end -}}
