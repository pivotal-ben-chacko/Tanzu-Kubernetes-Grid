#!/bin/bash 

export KUBECTL_VSPHERE_PASSWORD=$pass

  kubectl vsphere login --vsphere-username=administrator@vsphere.local --server=<supervisor-server> --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace dev_namespace
  kubectl vsphere login --vsphere-username=administrator@vsphere.local --server=<supervisor-server> --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace dev_namespace --tanzu-kubernetes-cluster-name services
  kubectl vsphere login --vsphere-username=administrator@vsphere.local --server=<supervisor-server> --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace dev_namespace --tanzu-kubernetes-cluster-name workload
