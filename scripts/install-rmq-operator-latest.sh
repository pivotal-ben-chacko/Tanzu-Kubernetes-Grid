#!/bin/bash

# --- Usage ---------------------------------------------------------------
#
# ./install-rmq-operator-latest.sh <option>
#
# Options:
#  --test    Enable smoke test which validates a RabbitMQ instance can be created 
#
# Note: This walkthrough uses an example of the RabbitMQ Cluster Kubernetes operator, 
# however it should be noted that the setup steps listed here remain largely the same 
# for any compatible operator. Note: This walkthrough uses the open source RabbitMQ 
# Cluster Operator for Kubernetes. However for most real world deployments it is 
# recommended to use the official, supported version provided by VMware - VMware Tanzu 
# RabbitMQ for Kubernetes.
#
# -------------------------------------------------------------------------

# create a ClusterRole that defines the rules and label it so that the rules are aggregated 
# to the appropriate controller.


# Check if smoke test required
if [ "$1" = "--test" ]; then
  SMOKE_TEST=true
else
  SMOKE_TEST=""
fi

gen_rmq_crb () {
cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-rmq
  labels:
    servicebinding.io/controller: "true"
rules:
- apiGroups: ["rabbitmq.com"]
  resources: ["rabbitmqclusters"]
  verbs: ["get", "list", "watch"]
EOF
}


# Make the new API discoverable to application operators.

gen_rmq_cluster_class () {
cat <<EOF | kubectl apply -f -
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: rabbitmq
spec:
  description:
    short: It's a RabbitMQ cluster!
  pool:
    group: rabbitmq.com
    kind: RabbitmqCluster
EOF
}


# By default, you can only claim and bind to service instances that are running in the 
# same namespace as the application workloads. To claim service instances running in a 
# different namespace, you must create a resource claim policy.

gen_rmq_resource_claim_policy () {
cat <<EOF | kubectl apply -f -
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: rabbitmqcluster-cross-namespace
  namespace: rmq-service-instances
spec:
  consumingNamespaces:
  - '*'
  subject:
    group: rabbitmq.com
    kind: RabbitmqCluster
EOF
}

gen_sample_instance () {
cat > sample-rmq-service-instance.yaml << EOF
---
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: rmq-1
  namespace: rmq-service-instances
EOF
}

smoke_test () {
  count=0
  while [ $count -lt 10 ] 
  do
    echo INFO: Waiting for RabbitMQ operator to be ready...
    kubectl get pod -n rabbitmq-system | grep -i "running"
    if [ $? -eq 0 ]; then
      echo INFO: RabbitMQ operator test pass!
      break
    fi
    count=$(($count + 1))
    if [ $count -lt 10 ]; then
      sleep 1
    else
      echo ERROR: RabbitMQ operator never became healthy...
    fi
  done
  
  echo INFO: Create RabbitMQ service instance...
  kubectl apply -f sample-rmq-service-instance.yaml
  count=0
  while [ $count -lt 60 ]
  do
    echo INFO: Waiting for RabbitMQ instance to be ready...
    kubectl get RabbitmqCluster -A | grep -i "true.*true"
    if [ $? -eq 0 ]; then
      echo INFO: RabbitMQ instance test pass!
      break
    fi
    count=$(($count + 1))
    if [ $count -lt 60 ]; then
      sleep 1
    else
      echo ERROR: RabbitMQ instance never became healthy...
    fi
  done

  echo INFO: Cleaning up...         
  kubectl delete -f sample-rmq-service-instance.yaml &> /dev/null
}
 
echo INFO: Installing RabbitMQ Operator
kapp -y deploy --app rmq-operator --file https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml

kubectl create ns rmq-service-instances

# Apply resources and policies
echo INFO: Applying cluster role...
gen_rmq_crb

echo INFO: Applying cluster instance...
gen_rmq_cluster_class

echo INFO: Create a resource claim policy...
gen_rmq_resource_claim_policy

gen_sample_instance

# Run smoke test if requested
if [ ! -z $SMOKE_TEST ]; then
  smoke_test
fi

echo
echo
echo "Run 'kubectl apply -f sample-rmq-service-instance.yaml' to create a rabbit service instance."
echo "Run 'tanzu service claim create rmq-1 --resource-name rmq-1 --resource-namespace rmq-service-instances --resource-kind RabbitmqCluster --resource-api-version rabbitmq.com/v1beta1' to make the service claim."
