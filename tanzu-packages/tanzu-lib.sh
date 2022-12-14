#!/bin/bash

cluster-rolebinding-apply () {
  kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-restricted --group=system:authenticated
}

tanzu-packages-ns-create () {
  kubectl create namespace tanzu-packages
}

tanzu-repo-16-add () {
  tanzu package repository add tkg-repo -n tanzu-package-repo-global --url projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.0
}

countour_values_gen () {
cat > $TANZU_CONTOUR_VALUES_FILE << EOF
---
infrastructure_provider: vsphere
namespace: tanzu-system-ingress
contour:
 configFileContents: {}
 useProxyProtocol: false
 replicas: 2
 pspNames: "vmware-system-restricted"
 logLevel: info
envoy:
 service:
   type: LoadBalancer
   annotations: {}
   nodePorts:
     http: null
     https: null
   externalTrafficPolicy: Cluster
   disableWait: false
 hostPorts:
   enable: true
   http: 80
   https: 443
 hostNetwork: false
 terminationGracePeriodSeconds: 300
 logLevel: info
 pspNames: null
certificates:
 duration: 8760h
 renewBefore: 360h
EOF
}


kapp-controller-psp-apply () {
cat <<EOF | kubectl apply -f -

apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: tanzu-system-kapp-ctrl-restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - configMap
    - emptyDir
    - projected
    - secret
    - downwardAPI
    - persistentVolumeClaim
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: MustRunAs
    ranges:
      - min: 1
        max: 65535
  fsGroup:
    rule: MustRunAs
    ranges:
      - min: 1
        max: 65535
  readOnlyRootFilesystem: false
EOF
}


kapp-controller-apply () {
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: tkg-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: tanzu-package-repo-global
---
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1alpha1.data.packaging.carvel.dev
spec:
  group: data.packaging.carvel.dev
  groupPriorityMinimum: 100
  service:
    name: packaging-api
    namespace: tkg-system
  version: v1alpha1
  versionPriority: 100
---
apiVersion: v1
kind: Service
metadata:
  name: packaging-api
  namespace: tkg-system
spec:
  ports:
  - port: 443
    protocol: TCP
    targetPort: api
  selector:
    app: kapp-controller
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: internalpackagemetadatas.internal.packaging.carvel.dev
spec:
  group: internal.packaging.carvel.dev
  names:
    kind: InternalPackageMetadata
    listKind: InternalPackageMetadataList
    plural: internalpackagemetadatas
    singular: internalpackagemetadata
  scope: Namespaced
  versions:
  - name: v1alpha1
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            properties:
              categories:
                items:
                  type: string
                type: array
              displayName:
                type: string
              iconSVGBase64:
                type: string
              longDescription:
                type: string
              maintainers:
                items:
                  properties:
                    name:
                      type: string
                  type: object
                type: array
              providerName:
                type: string
              shortDescription:
                type: string
              supportDescription:
                type: string
            type: object
        required:
        - spec
        type: object
    served: true
    storage: true
    subresources:
      status: {}
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: internalpackages.internal.packaging.carvel.dev
spec:
  group: internal.packaging.carvel.dev
  names:
    kind: InternalPackage
    listKind: InternalPackageList
    plural: internalpackages
    singular: internalpackage
  scope: Namespaced
  versions:
  - name: v1alpha1
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            properties:
              capacityRequirementsDescription:
                type: string
              licenses:
                items:
                  type: string
                type: array
              refName:
                type: string
              releaseNotes:
                type: string
              releasedAt:
                format: date-time
                nullable: true
                type: string
              template:
                properties:
                  spec:
                    properties:
                      canceled:
                        description: Canceled when set to true will stop all active changes
                        type: boolean
                      cluster:
                        properties:
                          kubeconfigSecretRef:
                            properties:
                              key:
                                type: string
                              name:
                                type: string
                            type: object
                          namespace:
                            type: string
                        type: object
                      deploy:
                        items:
                          properties:
                            kapp:
                              properties:
                                delete:
                                  properties:
                                    rawOptions:
                                      items:
                                        type: string
                                      type: array
                                  type: object
                                inspect:
                                  properties:
                                    rawOptions:
                                      items:
                                        type: string
                                      type: array
                                  type: object
                                intoNs:
                                  type: string
                                mapNs:
                                  items:
                                    type: string
                                  type: array
                                rawOptions:
                                  items:
                                    type: string
                                  type: array
                              type: object
                          type: object
                        type: array
                      fetch:
                        items:
                          properties:
                            git:
                              description: TODO implement git
                              properties:
                                lfsSkipSmudge:
                                  type: boolean
                                ref:
                                  type: string
                                secretRef:
                                  description: 'Secret may include one or more keys: ssh-privatekey, ssh-knownhosts'
                                  properties:
                                    name:
                                      description: Object is expected to be within same namespace
                                      type: string
                                  type: object
                                subPath:
                                  type: string
                                url:
                                  type: string
                              type: object
                            helmChart:
                              properties:
                                name:
                                  description: 'Example: stable/redis'
                                  type: string
                                repository:
                                  properties:
                                    secretRef:
                                      properties:
                                        name:
                                          description: Object is expected to be within same namespace
                                          type: string
                                      type: object
                                    url:
                                      type: string
                                  type: object
                                version:
                                  type: string
                              type: object
                            http:
                              properties:
                                secretRef:
                                  description: 'Secret may include one or more keys: username, password'
                                  properties:
                                    name:
                                      description: Object is expected to be within same namespace
                                      type: string
                                  type: object
                                sha256:
                                  type: string
                                subPath:
                                  type: string
                                url:
                                  description: 'URL can point to one of following formats: text, tgz, zip'
                                  type: string
                              type: object
                            image:
                              properties:
                                secretRef:
                                  description: 'Secret may include one or more keys: username, password, token. By default anonymous access is used for authentication. TODO support docker config formated secret'
                                  properties:
                                    name:
                                      description: Object is expected to be within same namespace
                                      type: string
                                  type: object
                                subPath:
                                  type: string
                                url:
                                  description: 'Example: username/app1-config:v0.1.0'
                                  type: string
                              type: object
                            imgpkgBundle:
                              properties:
                                image:
                                  type: string
                                secretRef:
                                  description: 'Secret may include one or more keys: username, password, token. By default anonymous access is used for authentication. TODO support docker config formated secret'
                                  properties:
                                    name:
                                      description: Object is expected to be within same namespace
                                      type: string
                                  type: object
                              type: object
                            inline:
                              properties:
                                paths:
                                  additionalProperties:
                                    type: string
                                  type: object
                                pathsFrom:
                                  items:
                                    properties:
                                      configMapRef:
                                        properties:
                                          directoryPath:
                                            type: string
                                          name:
                                            type: string
                                        type: object
                                      secretRef:
                                        properties:
                                          directoryPath:
                                            type: string
                                          name:
                                            type: string
                                        type: object
                                    type: object
                                  type: array
                              type: object
                          type: object
                        type: array
                      noopDelete:
                        description: When NoopDeletion set to true, App deletion should delete App CR but preserve App's associated resources
                        type: boolean
                      paused:
                        description: Paused when set to true will ignore all pending changes, once it set back to false, pending changes will be applied
                        type: boolean
                      serviceAccountName:
                        type: string
                      syncPeriod:
                        description: Controls frequency of app reconciliation
                        type: string
                      template:
                        items:
                          properties:
                            helmTemplate:
                              properties:
                                name:
                                  type: string
                                namespace:
                                  type: string
                                path:
                                  type: string
                                valuesFrom:
                                  items:
                                    properties:
                                      configMapRef:
                                        properties:
                                          name:
                                            type: string
                                        type: object
                                      path:
                                        type: string
                                      secretRef:
                                        properties:
                                          name:
                                            type: string
                                        type: object
                                    type: object
                                  type: array
                              type: object
                            jsonnet:
                              description: TODO implement jsonnet
                              type: object
                            kbld:
                              properties:
                                paths:
                                  items:
                                    type: string
                                  type: array
                              type: object
                            kustomize:
                              description: TODO implement kustomize
                              type: object
                            sops:
                              properties:
                                paths:
                                  items:
                                    type: string
                                  type: array
                                pgp:
                                  properties:
                                    privateKeysSecretRef:
                                      properties:
                                        name:
                                          type: string
                                      type: object
                                  type: object
                              type: object
                            ytt:
                              properties:
                                fileMarks:
                                  items:
                                    type: string
                                  type: array
                                ignoreUnknownComments:
                                  type: boolean
                                inline:
                                  properties:
                                    paths:
                                      additionalProperties:
                                        type: string
                                      type: object
                                    pathsFrom:
                                      items:
                                        properties:
                                          configMapRef:
                                            properties:
                                              directoryPath:
                                                type: string
                                              name:
                                                type: string
                                            type: object
                                          secretRef:
                                            properties:
                                              directoryPath:
                                                type: string
                                              name:
                                                type: string
                                            type: object
                                        type: object
                                      type: array
                                  type: object
                                paths:
                                  items:
                                    type: string
                                  type: array
                                strict:
                                  type: boolean
                                valuesFrom:
                                  items:
                                    properties:
                                      configMapRef:
                                        properties:
                                          name:
                                            type: string
                                        type: object
                                      path:
                                        type: string
                                      secretRef:
                                        properties:
                                          name:
                                            type: string
                                        type: object
                                    type: object
                                  type: array
                              type: object
                          type: object
                        type: array
                    type: object
                required:
                - spec
                type: object
              valuesSchema:
                description: valuesSchema can be used to show template values that can be configured by users when a Package is installed in an OpenAPI schema format.
                properties:
                  openAPIv3:
                    nullable: true
                    type: object
                    x-kubernetes-preserve-unknown-fields: true
                type: object
              version:
                type: string
            type: object
        required:
        - spec
        type: object
    served: true
    storage: true
    subresources:
      status: {}
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: apps.kappctrl.k14s.io
spec:
  group: kappctrl.k14s.io
  names:
    kind: App
    listKind: AppList
    plural: apps
    singular: app
  scope: Namespaced
  versions:
  - additionalPrinterColumns:
    - description: Friendly description
      jsonPath: .status.friendlyDescription
      name: Description
      type: string
    - description: Last time app started being deployed. Does not mean anything was changed.
      jsonPath: .status.deploy.startedAt
      name: Since-Deploy
      type: date
    - description: Time since creation
      jsonPath: .metadata.creationTimestamp
      name: Age
      type: date
    name: v1alpha1
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            properties:
              canceled:
                description: Canceled when set to true will stop all active changes
                type: boolean
              cluster:
                properties:
                  kubeconfigSecretRef:
                    properties:
                      key:
                        type: string
                      name:
                        type: string
                    type: object
                  namespace:
                    type: string
                type: object
              deploy:
                items:
                  properties:
                    kapp:
                      properties:
                        delete:
                          properties:
                            rawOptions:
                              items:
                                type: string
                              type: array
                          type: object
                        inspect:
                          properties:
                            rawOptions:
                              items:
                                type: string
                              type: array
                          type: object
                        intoNs:
                          type: string
                        mapNs:
                          items:
                            type: string
                          type: array
                        rawOptions:
                          items:
                            type: string
                          type: array
                      type: object
                  type: object
                type: array
              fetch:
                items:
                  properties:
                    git:
                      description: TODO implement git
                      properties:
                        lfsSkipSmudge:
                          type: boolean
                        ref:
                          type: string
                        secretRef:
                          description: 'Secret may include one or more keys: ssh-privatekey, ssh-knownhosts'
                          properties:
                            name:
                              description: Object is expected to be within same namespace
                              type: string
                          type: object
                        subPath:
                          type: string
                        url:
                          type: string
                      type: object
                    helmChart:
                      properties:
                        name:
                          description: 'Example: stable/redis'
                          type: string
                        repository:
                          properties:
                            secretRef:
                              properties:
                                name:
                                  description: Object is expected to be within same namespace
                                  type: string
                              type: object
                            url:
                              type: string
                          type: object
                        version:
                          type: string
                      type: object
                    http:
                      properties:
                        secretRef:
                          description: 'Secret may include one or more keys: username, password'
                          properties:
                            name:
                              description: Object is expected to be within same namespace
                              type: string
                          type: object
                        sha256:
                          type: string
                        subPath:
                          type: string
                        url:
                          description: 'URL can point to one of following formats: text, tgz, zip'
                          type: string
                      type: object
                    image:
                      properties:
                        secretRef:
                          description: 'Secret may include one or more keys: username, password, token. By default anonymous access is used for authentication. TODO support docker config formated secret'
                          properties:
                            name:
                              description: Object is expected to be within same namespace
                              type: string
                          type: object
                        subPath:
                          type: string
                        url:
                          description: 'Example: username/app1-config:v0.1.0'
                          type: string
                      type: object
                    imgpkgBundle:
                      properties:
                        image:
                          type: string
                        secretRef:
                          description: 'Secret may include one or more keys: username, password, token. By default anonymous access is used for authentication. TODO support docker config formated secret'
                          properties:
                            name:
                              description: Object is expected to be within same namespace
                              type: string
                          type: object
                      type: object
                    inline:
                      properties:
                        paths:
                          additionalProperties:
                            type: string
                          type: object
                        pathsFrom:
                          items:
                            properties:
                              configMapRef:
                                properties:
                                  directoryPath:
                                    type: string
                                  name:
                                    type: string
                                type: object
                              secretRef:
                                properties:
                                  directoryPath:
                                    type: string
                                  name:
                                    type: string
                                type: object
                            type: object
                          type: array
                      type: object
                  type: object
                type: array
              noopDelete:
                description: When NoopDeletion set to true, App deletion should delete App CR but preserve App's associated resources
                type: boolean
              paused:
                description: Paused when set to true will ignore all pending changes, once it set back to false, pending changes will be applied
                type: boolean
              serviceAccountName:
                type: string
              syncPeriod:
                description: Controls frequency of app reconciliation
                type: string
              template:
                items:
                  properties:
                    helmTemplate:
                      properties:
                        name:
                          type: string
                        namespace:
                          type: string
                        path:
                          type: string
                        valuesFrom:
                          items:
                            properties:
                              configMapRef:
                                properties:
                                  name:
                                    type: string
                                type: object
                              path:
                                type: string
                              secretRef:
                                properties:
                                  name:
                                    type: string
                                type: object
                            type: object
                          type: array
                      type: object
                    jsonnet:
                      description: TODO implement jsonnet
                      type: object
                    kbld:
                      properties:
                        paths:
                          items:
                            type: string
                          type: array
                      type: object
                    kustomize:
                      description: TODO implement kustomize
                      type: object
                    sops:
                      properties:
                        paths:
                          items:
                            type: string
                          type: array
                        pgp:
                          properties:
                            privateKeysSecretRef:
                              properties:
                                name:
                                  type: string
                              type: object
                          type: object
                      type: object
                    ytt:
                      properties:
                        fileMarks:
                          items:
                            type: string
                          type: array
                        ignoreUnknownComments:
                          type: boolean
                        inline:
                          properties:
                            paths:
                              additionalProperties:
                                type: string
                              type: object
                            pathsFrom:
                              items:
                                properties:
                                  configMapRef:
                                    properties:
                                      directoryPath:
                                        type: string
                                      name:
                                        type: string
                                    type: object
                                  secretRef:
                                    properties:
                                      directoryPath:
                                        type: string
                                      name:
                                        type: string
                                    type: object
                                type: object
                              type: array
                          type: object
                        paths:
                          items:
                            type: string
                          type: array
                        strict:
                          type: boolean
                        valuesFrom:
                          items:
                            properties:
                              configMapRef:
                                properties:
                                  name:
                                    type: string
                                type: object
                              path:
                                type: string
                              secretRef:
                                properties:
                                  name:
                                    type: string
                                type: object
                            type: object
                          type: array
                      type: object
                  type: object
                type: array
            type: object
          status:
            properties:
              conditions:
                items:
                  description: TODO rename to Condition
                  properties:
                    message:
                      description: Human-readable message indicating details about last transition.
                      type: string
                    reason:
                      description: Unique, this should be a short, machine understandable string that gives the reason for condition's last transition. If it reports "ResizeStarted" that means the underlying persistent volume is being resized.
                      type: string
                    status:
                      type: string
                    type:
                      type: string
                  required:
                  - status
                  - type
                  type: object
                type: array
              consecutiveReconcileFailures:
                type: integer
              consecutiveReconcileSuccesses:
                type: integer
              deploy:
                properties:
                  error:
                    type: string
                  exitCode:
                    type: integer
                  finished:
                    type: boolean
                  startedAt:
                    format: date-time
                    type: string
                  stderr:
                    type: string
                  stdout:
                    type: string
                  updatedAt:
                    format: date-time
                    type: string
                type: object
              fetch:
                properties:
                  error:
                    type: string
                  exitCode:
                    type: integer
                  startedAt:
                    format: date-time
                    type: string
                  stderr:
                    type: string
                  stdout:
                    type: string
                  updatedAt:
                    format: date-time
                    type: string
                type: object
              friendlyDescription:
                type: string
              inspect:
                properties:
                  error:
                    type: string
                  exitCode:
                    type: integer
                  stderr:
                    type: string
                  stdout:
                    type: string
                  updatedAt:
                    format: date-time
                    type: string
                type: object
              managedAppName:
                type: string
              observedGeneration:
                format: int64
                type: integer
              template:
                properties:
                  error:
                    type: string
                  exitCode:
                    type: integer
                  stderr:
                    type: string
                  updatedAt:
                    format: date-time
                    type: string
                type: object
              usefulErrorMessage:
                type: string
            type: object
        required:
        - spec
        type: object
    served: true
    storage: true
    subresources:
      status: {}
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: packageinstalls.packaging.carvel.dev
spec:
  group: packaging.carvel.dev
  names:
    kind: PackageInstall
    listKind: PackageInstallList
    plural: packageinstalls
    shortNames:
    - pkgi
    singular: packageinstall
  scope: Namespaced
  versions:
  - additionalPrinterColumns:
    - description: PackageMetadata name
      jsonPath: .spec.packageRef.refName
      name: Package name
      type: string
    - description: PackageMetadata version
      jsonPath: .status.version
      name: Package version
      type: string
    - description: Friendly description
      jsonPath: .status.friendlyDescription
      name: Description
      type: string
    - description: Time since creation
      jsonPath: .metadata.creationTimestamp
      name: Age
      type: date
    name: v1alpha1
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            properties:
              canceled:
                description: Canceled when set to true will stop all active changes
                type: boolean
              cluster:
                properties:
                  kubeconfigSecretRef:
                    properties:
                      key:
                        type: string
                      name:
                        type: string
                    type: object
                  namespace:
                    type: string
                type: object
              noopDelete:
                description: When NoopDelete set to true, PackageInstall deletion should delete PackageInstall/App CR but preserve App's associated resources.
                type: boolean
              packageRef:
                properties:
                  refName:
                    type: string
                  versionSelection:
                    properties:
                      constraints:
                        type: string
                      prereleases:
                        properties:
                          identifiers:
                            items:
                              type: string
                            type: array
                        type: object
                    type: object
                type: object
              paused:
                description: Paused when set to true will ignore all pending changes, once it set back to false, pending changes will be applied
                type: boolean
              serviceAccountName:
                type: string
              syncPeriod:
                description: Controls frequency of App reconciliation in time + unit format. Always >= 30s. If value below 30s is specified, 30s will be used.
                type: string
              values:
                items:
                  properties:
                    secretRef:
                      properties:
                        key:
                          type: string
                        name:
                          type: string
                      type: object
                  type: object
                type: array
            type: object
          status:
            properties:
              conditions:
                items:
                  description: TODO rename to Condition
                  properties:
                    message:
                      description: Human-readable message indicating details about last transition.
                      type: string
                    reason:
                      description: Unique, this should be a short, machine understandable string that gives the reason for condition's last transition. If it reports "ResizeStarted" that means the underlying persistent volume is being resized.
                      type: string
                    status:
                      type: string
                    type:
                      type: string
                  required:
                  - status
                  - type
                  type: object
                type: array
              friendlyDescription:
                type: string
              observedGeneration:
                format: int64
                type: integer
              usefulErrorMessage:
                type: string
              version:
                description: TODO this is desired resolved version (not actually deployed)
                type: string
            type: object
        required:
        - spec
        type: object
    served: true
    storage: true
    subresources:
      status: {}
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    packaging.carvel.dev/global-namespace: tanzu-package-repo-global
  name: packagerepositories.packaging.carvel.dev
spec:
  group: packaging.carvel.dev
  names:
    kind: PackageRepository
    listKind: PackageRepositoryList
    plural: packagerepositories
    shortNames:
    - pkgr
    singular: packagerepository
  scope: Namespaced
  versions:
  - additionalPrinterColumns:
    - description: Time since creation
      jsonPath: .metadata.creationTimestamp
      name: Age
      type: date
    - description: Friendly description
      jsonPath: .status.friendlyDescription
      name: Description
      type: string
    name: v1alpha1
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            properties:
              fetch:
                properties:
                  git:
                    description: TODO implement git
                    properties:
                      lfsSkipSmudge:
                        type: boolean
                      ref:
                        type: string
                      secretRef:
                        description: 'Secret may include one or more keys: ssh-privatekey, ssh-knownhosts'
                        properties:
                          name:
                            description: Object is expected to be within same namespace
                            type: string
                        type: object
                      subPath:
                        type: string
                      url:
                        type: string
                    type: object
                  http:
                    properties:
                      secretRef:
                        description: 'Secret may include one or more keys: username, password'
                        properties:
                          name:
                            description: Object is expected to be within same namespace
                            type: string
                        type: object
                      sha256:
                        type: string
                      subPath:
                        type: string
                      url:
                        description: 'URL can point to one of following formats: text, tgz, zip'
                        type: string
                    type: object
                  image:
                    properties:
                      secretRef:
                        description: 'Secret may include one or more keys: username, password, token. By default anonymous access is used for authentication. TODO support docker config formated secret'
                        properties:
                          name:
                            description: Object is expected to be within same namespace
                            type: string
                        type: object
                      subPath:
                        type: string
                      url:
                        description: 'Example: username/app1-config:v0.1.0'
                        type: string
                    type: object
                  imgpkgBundle:
                    properties:
                      image:
                        type: string
                      secretRef:
                        description: 'Secret may include one or more keys: username, password, token. By default anonymous access is used for authentication. TODO support docker config formated secret'
                        properties:
                          name:
                            description: Object is expected to be within same namespace
                            type: string
                        type: object
                    type: object
                type: object
              paused:
                description: Paused when set to true will ignore all pending changes, once it set back to false, pending changes will be applied
                type: boolean
              syncPeriod:
                description: Controls frequency of PackageRepository reconciliation
                type: string
            required:
            - fetch
            type: object
          status:
            properties:
              conditions:
                items:
                  description: TODO rename to Condition
                  properties:
                    message:
                      description: Human-readable message indicating details about last transition.
                      type: string
                    reason:
                      description: Unique, this should be a short, machine understandable string that gives the reason for condition's last transition. If it reports "ResizeStarted" that means the underlying persistent volume is being resized.
                      type: string
                    status:
                      type: string
                    type:
                      type: string
                  required:
                  - status
                  - type
                  type: object
                type: array
              consecutiveReconcileFailures:
                type: integer
              consecutiveReconcileSuccesses:
                type: integer
              deploy:
                properties:
                  error:
                    type: string
                  exitCode:
                    type: integer
                  finished:
                    type: boolean
                  startedAt:
                    format: date-time
                    type: string
                  stderr:
                    type: string
                  stdout:
                    type: string
                  updatedAt:
                    format: date-time
                    type: string
                type: object
              fetch:
                properties:
                  error:
                    type: string
                  exitCode:
                    type: integer
                  startedAt:
                    format: date-time
                    type: string
                  stderr:
                    type: string
                  stdout:
                    type: string
                  updatedAt:
                    format: date-time
                    type: string
                type: object
              friendlyDescription:
                type: string
              observedGeneration:
                format: int64
                type: integer
              template:
                properties:
                  error:
                    type: string
                  exitCode:
                    type: integer
                  stderr:
                    type: string
                  updatedAt:
                    format: date-time
                    type: string
                type: object
              usefulErrorMessage:
                type: string
            type: object
        required:
        - spec
        type: object
    served: true
    storage: true
    subresources:
      status: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kapp-controller-config
  namespace: tkg-system
  annotations:
    kapp.k14s.io/change-group: apps.kappctrl.k14s.io/kapp-controller-config
data:
  caCerts: ""
  httpProxy: ""
  httpsProxy: ""
  noProxy: ""
  dangerousSkipTLSVerify: ""
---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    kapp-controller.carvel.dev/version: v0.30.0
    kapp.k14s.io/change-rule: upsert after upserting apps.kappctrl.k14s.io/kapp-controller-config
  name: kapp-controller
  namespace: tkg-system
spec:
  replicas: 1
  revisionHistoryLimit: 0
  selector:
    matchLabels:
      app: kapp-controller
  template:
    metadata:
      labels:
        app: kapp-controller
    spec:
      containers:
      - args:
        - -packaging-global-namespace=tanzu-package-repo-global
        - -concurrency=4
        env:
        - name: KAPPCTRL_MEM_TMP_DIR
          value: /etc/kappctrl-mem-tmp
        - name: KAPPCTRL_SYSTEM_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: KAPPCTRL_API_PORT
          value: "10350"
        image: projects.registry.vmware.com/tkg/kapp-controller:v0.30.0_vmware.1
        name: kapp-controller
        ports:
        - containerPort: 10350
          name: api
          protocol: TCP
        resources:
          requests:
            cpu: 120m
            memory: 100Mi
        securityContext:
          runAsGroup: 2000
          runAsUser: 1000
        volumeMounts:
        - mountPath: /etc/kappctrl-mem-tmp
          name: template-fs
      securityContext:
        fsGroup: 3000
      serviceAccount: kapp-controller-sa
      volumes:
      - emptyDir:
          medium: Memory
        name: template-fs
      priorityClassName: system-cluster-critical
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
      - effect: NoSchedule
        key: node.kubernetes.io/not-ready
      - effect: NoSchedule
        key: node.cloudprovider.kubernetes.io/uninitialized
        value: "true"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kapp-controller-sa
  namespace: tkg-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kapp-controller-cluster-role
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - create
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - serviceaccounts
  verbs:
  - get
- apiGroups:
  - kappctrl.k14s.io
  resources:
  - apps
  - apps/status
  verbs:
  - '*'
- apiGroups:
  - packaging.carvel.dev
  resources:
  - packageinstalls
  - packageinstalls/status
  verbs:
  - '*'
- apiGroups:
  - packaging.carvel.dev
  resources:
  - packagerepositories
  - packagerepositories/status
  verbs:
  - '*'
- apiGroups:
  - internal.packaging.carvel.dev
  resources:
  - internalpackagemetadatas
  verbs:
  - '*'
- apiGroups:
  - data.packaging.carvel.dev
  resources:
  - packagemetadatas
  - packagemetadatas/status
  verbs:
  - '*'
- apiGroups:
  - internal.packaging.carvel.dev
  resources:
  - internalpackages
  verbs:
  - '*'
- apiGroups:
  - data.packaging.carvel.dev
  resources:
  - packages
  - packages/status
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - '*'
- apiGroups:
  - apiregistration.k8s.io
  resources:
  - apiservices
  verbs:
  - update
  - get
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - list
  - watch
  - get
  - update
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - mutatingwebhookconfigurations
  verbs:
  - list
  - watch
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - validatingwebhookconfigurations
  verbs:
  - list
  - watch
- apiGroups:
  - policy
  resources:
  - podsecuritypolicies
  resourceNames:
  - tanzu-system-kapp-ctrl-restricted
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kapp-controller-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kapp-controller-cluster-role
subjects:
- kind: ServiceAccount
  name: kapp-controller-sa
  namespace: tkg-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pkg-apiserver:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: kapp-controller-sa
  namespace: tkg-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pkgserver-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: kapp-controller-sa
  namespace: tkg-system
EOF
}


