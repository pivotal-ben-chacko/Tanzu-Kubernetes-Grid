#!/bin/bash

set -e 


# --- Usage ---------------------------------------------------------------
#
# ./install-psql-operator-1-8.sh <options>
#
# Options:
#  --ag    Initiate airgapped install
#          Note: Postgres operator package must be in the current working dir, 
#                named: postgres-for-kubernetes-v1.8.0.tar.gz
#
# -------------------------------------------------------------------------
#
# --- Enter Pivnet Legacy API token if not using airgapped install     ----

APITOKEN="xxxxxxxxxx"

# -------------------------------------------------------------------------

# --- Set this to your private registry if using airgapped installation ---
# --- otherwise leave it as the tanzu registry creds                    ---

REGISTRY="harbor.skynetsystems.io"
REGISTRY_USERNAME="admin"
REGISTRY_PASS="changeme"
REGISTRY_PROJECT="tap"

# -------------------------------------------------------------------------
# -------------------------------------------------------------------------

PSQLFILE="postgres-for-kubernetes-v1.8.0"

SEARCH_STR_1="registry.tanzu.vmware.com"
SEARCH_STR_2="tanzu-sql-postgres"

# Check if air-gapped install
if [ "$1" = "--ag" ]; then
  AIR_GAPPED=true
else
  AIR_GAPPED=""
fi

# create a ClusterRole that defines the rules and label it so that the rules are aggregated 
# to the appropriate controller.

gen_psql_crb () {
cat <<EOF | kubectl apply -f -
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
cat <<EOF | kubectl apply -f -
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
cat <<EOF | kubectl apply -f -
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


# Create namespace where Postgres Operator should be installed to
# kubectl create namespace postgres-operator
# Create a docker-registry type secret to allow the Kubernetes cluster to authenticate with the private container registry
  kubectl create secret docker-registry regsecret --docker-server=$REGISTRY --docker-username=$REGISTRY_USERNAME \
    --docker-password=$REGISTRY_PASS --namespace=postgres-operator

if [ -z $AIR_GAPPED ]; then
  if [ ! -f ${PSQLFILE}.tar.gz ]; then
    curl "https://network.pivotal.io/api/v2/products/tanzu-sql-postgres/releases/1124725/product_files/1260935/download" -H "Authorization: Token $APITOKEN" -L --output postgres-for-kubernetes-v1.8.0.tar.gz
  else
    echo INFO: File already exists, skipping download...
  fi
fi

# Untar the postgres tarball
if [ ! -d ${PSQLFILE} ]; then
  echo INFO: Extracting tarbal...
  tar -xzf postgres-for-kubernetes-v1.8.0.tar.gz
else 
  echo INFO: File already extracted, skipping...
fi

cd ./$PSQLFILE

if [ ! -z $AIR_GAPPED ]; then
  # Load postgres images into docker
  echo "INFO: Loading images into docker..."
  docker load -i ./images/postgres-instance
  docker load -i ./images/postgres-operator

  docker images "postgres-*"
  docker login $REGISTRY

  # Push Postgres instance to registry
  INSTANCE_IMAGE_NAME="${REGISTRY}/${REGISTRY_PROJECT}/postgres-instance:$(cat ./images/postgres-instance-tag)"
  docker tag $(cat ./images/postgres-instance-id) ${INSTANCE_IMAGE_NAME}
  docker push ${INSTANCE_IMAGE_NAME}

  # Push Postgres operator to registry
  OPERATOR_IMAGE_NAME="${REGISTRY}/${REGISTRY_PROJECT}/postgres-operator:$(cat ./images/postgres-operator-tag)"
  docker tag $(cat ./images/postgres-operator-id) ${OPERATOR_IMAGE_NAME}
  docker push ${OPERATOR_IMAGE_NAME}
  
  # Update values file 
  FILE=./operator/values.yaml
  echo "INFO: Updating values file..."
  if grep -q "$SEARCH_STR_1" "$FILE"; then
    sed -i "s/${SEARCH_STR_1}/${REGISTRY}/" ${FILE}
  fi

  if grep -q "$SEARCH_STR_2" "$FILE"; then
    sed -i "s/${SEARCH_STR_2}/${REGISTRY_PROJECT}/" ${FILE}
  fi
fi

# Enable Open Container Initiative (OCI)
export HELM_EXPERIMENTAL_OCI=1

# Install Postgres Operator
helm registry login $REGISTRY --username=$REGISTRY_USERNAME --password=$REGISTRY_PASS
helm install postgres-operator operator/ --values=operator/values.yaml --namespace=postgres-operator --wait

# Apply resources and policies
echo INFO: Applying cluster role...
gen_psql_crb

echo INFO: Applying cluster instance...
gen_psql_cluster_class

echo INFO: Create a resource claim policy...
gen_psql_resource_claim_policy

gen_sample_instance
echo
echo
echo "Run 'kubectl apply -f postgres-for-kubernetes-v1.8.0/sample-psql-service-instance.yaml' to create a postgres service instance."
echo "Run 'tanzu service claim create psql-1 --resource-name psql-1 --resource-namespace psql-service-instances --resource-kind Postgres --resource-api-version sql.tanzu.vmware.com/v1 -n default' to make the service claim."
