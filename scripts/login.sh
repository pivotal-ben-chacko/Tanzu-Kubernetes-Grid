#!/bin/bash

cleanup () {
 unset  KUBECTL_VSPHERE_PASSWORD
}

trap cleanup SIGTERM

# replace with base64 encoded password for vsphere
KUBECTL_VSPHERE_PASSWORD_B64="changeme"

alias k=kubectl
alias krr="kubectl rollout restart"
alias kcg="kubectl config get-contexts"
alias kcu="kubectl config use-context"

alias kgp="kubectl get pod"
alias kgs="kubectl get service"
alias kgd="kubectl get deploy"
alias kgi="kubectl get ingress"
alias kgc="kubectl get configmap"
alias kgn="kubectl get namespace"
alias kgnode="kubectl get node"

export KUBECTL_VSPHERE_PASSWORD=`echo $KUBECTL_VSPHERE_PASSWORD_B64 | base64 -d`
kubectl vsphere login --vsphere-username=$user@vsphere.local --server=vc01cl01-wcp.h2o-2-2086.h2o.vmware.com --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace h2o --tanzu-kubernetes-cluster-name workload

kubectl vsphere login --vsphere-username=$user@vsphere.local --server=vc01cl01-wcp.h2o-2-2086.h2o.vmware.com --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace h2o --tanzu-kubernetes-cluster-name worker

cleanup
