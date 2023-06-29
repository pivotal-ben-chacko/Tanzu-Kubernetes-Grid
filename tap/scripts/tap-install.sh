#!/bin/bash

export INSTALL_REGISTRY_USERNAME=
export INSTALL_REGISTRY_PASSWORD=
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export TAP_VERSION="1.6.0-rc.2"
export INSTALL_REPO=tanzu-application-platform

NS=dev

kubectl create ns tap-install
kubectl create ns $NS

tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} \
  --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces \
  --yes \
  --namespace tap-install

tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages:$TAP_VERSION \
  --namespace tap-install

tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yaml -n tap-install

tanzu secret registry add registry-credentials \
  --server harbor.skynetsystems.io \
  --username admin \
  --password changeme \
  --namespace $NS

cat <<EOF | kubectl -n $NS apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
EOF

# Use to find all available TAP releases
# imgpkg tag list -i registry.tanzu.vmware.com/tanzu-application-platform/tap-packages | grep -v sha256 | cut -c 1-5 | sort -ru

# tanzu package install external-secrets --package-name external-secrets.apps.tanzu.vmware.com --version 0.6.1+tap.4 --namespace tap-install
# tanzu package repository get tanzu-tap-repository --namespace tap-install
# tanzu plugin install --local cli all
