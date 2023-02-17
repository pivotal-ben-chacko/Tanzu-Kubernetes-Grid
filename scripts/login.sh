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

# short alias to set/show context/namespace (only works for bash and bash-compatible shells, current context to be set before using kn to set namespace) 
alias kx='f() { [ "$1" ] && kubectl config use-context $1 || kubectl config current-context ; } ; f'
alias kn='f() { [ "$1" ] && kubectl config set-context --current --namespace $1 || kubectl config view --minify | grep namespace | cut -d" " -f6 ; } ; f'

alias kp="kubectl get pod"
alias ks="kubectl get service"
alias kd="kubectl get deploy"
alias ki="kubectl get ingress"
alias kc="kubectl get configmap"
alias kn="kubectl get namespace"
alias knode="kubectl get node"
alias ktkr="kubectl get tkr"
alias ktkc="kubectl get tkc -A"

# ---- user defined ----- 
user=
server=
namespace=
cluster=
# -----------------------

export KUBECTL_VSPHERE_PASSWORD=`echo $KUBECTL_VSPHERE_PASSWORD_B64 | base64 -d`

kubectl vsphere login --vsphere-username=$user@vsphere.local --server=$server --insecure-skip-tls-verify

if [ -n "$namespace" ]; then
  kubectl vsphere login --vsphere-username=$user@vsphere.local --server=$server --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace $namespace --tanzu-kubernetes-cluster-name $cluster
fi

cleanup
