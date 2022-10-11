#!/bin/bash

set -e 

# Enter your PivNet Legacy API token
APITOKEN="xxxxxxxx"

PSQLFILE="postgres-for-kubernetes-v1.8.0"
REGISTRY="harbor.skynetsystems.io"
PROJECT="tap"

psqlFiles=("psql-cluster-rbc.yaml" "psql-cluster-class.yaml" "psql-resource-claim-policy.yaml")

check_tools () {
  if [ ! command -v imgpkg &> /dev/null ]; then
    echo "Please install imgpkg"
  elif [ ! command -v yq &> /dev/null ]; then
    echo "Please install yq"
  fi
}


# create a ClusterRole that defines the rules and label it so that the rules are aggregated 
# to the appropriate controller.

gen_psql_crb () {
cat > ${psqlFiles[0]} << EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-postgres
  labels:
    resourceclaims.services.apps.tanzu.vmware.com/controller: "true"
rules:
- apiGroups: ["sql.tanzu.vmware.com"]
  resources: ["postgres"]
  verbs: ["get", "list", "watch", "update"]
EOF
}


# Make the new API discoverable to application operators.

gen_psql_cluster_class () {
cat > ${psqlFiles[1]} << EOF
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: postgres
spec:
  description:
    short: It's a Postgres cluster!
  pool:
    group: sql.tanzu.vmware.com
    kind: Postgres
EOF
}


# By default, you can only claim and bind to service instances that are running in the 
# same namespace as the application workloads. To claim service instances running in a 
# different namespace, you must create a resource claim policy.

gen_psql_resource_claim_policy () {
cat > ${psqlFiles[2]} << EOF
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: postgres-cross-namespace
  namespace: psql-service-instances
spec:
  consumingNamespaces:
  - '*'
  subject:
    group: sql.tanzu.vmware.com
    kind: Postgres
EOF
}

gen_sample_instance () {
cat > sample-psql-service-instance.yaml << EOF
---
apiVersion: sql.tanzu.vmware.com/v1
kind: Postgres
metadata:
  name: psql-1
  namespace: default
spec:
  storageClassName: default
  monitorStorageClassName: default
EOF
}

check_tools

if [ ! -f ${PSQLFILE}.tar.gz ]; then
  curl "https://network.pivotal.io/api/v2/products/tanzu-sql-postgres/releases/1124725/product_files/1260935/download" -H "Authorization: Token $APITOKEN" -L --output postgres-for-kubernetes-v1.8.0.tar.gz
else
  echo INFO: File already exists, skipping download...
fi

# Untar the postgres tarball
if [ ! -d ${PSQLFILE} ]; then
  tar -xzf postgres-for-kubernetes-v1.8.0.tar.gz
else 
  echo INFO: File already extracted, skipping...
fi

cd ./$PSQLFILE

# Load postgres images into docker
docker load -i ./images/postgres-instance
docker load -i ./images/postgres-operator

docker images "postgres-*"

docker login $REGISTRY

# Push Postgres instance to registry
INSTANCE_IMAGE_NAME="${REGISTRY}/${PROJECT}/postgres-instance:$(cat ./images/postgres-instance-tag)"
docker tag $(cat ./images/postgres-instance-id) ${INSTANCE_IMAGE_NAME}
docker push ${INSTANCE_IMAGE_NAME}

# Push Postgres operator to registry
OPERATOR_IMAGE_NAME="${REGISTRY}/${PROJECT}/postgres-operator:$(cat ./images/postgres-operator-tag)"
docker tag $(cat ./images/postgres-operator-id) ${OPERATOR_IMAGE_NAME}
docker push ${OPERATOR_IMAGE_NAME}

# Apply resources and policies
gen_psql_crb
kubectl apply -f ${psqlFiles[0]}

gen_psql_cluster_class
kubectl apply -f ${psqlFiles[1]}

gen_psql_resource_claim_policy
kubectl apply -f ${psqlFiles[2]}

gen_sample_instance
echo "Run 'kubectl apply -f postgres-for-kubernetes-v1.8.0/sample-psql-service-instance.yaml' to create a postgres service instance."
echo "Run 'tanzu service claim create psql-1 --resource-name psql-1 --resource-namespace psql-service-instances --resource-kind Postgres --resource-api-version sql.tanzu.vmware.com/v1 -n default' to make the service claim."
