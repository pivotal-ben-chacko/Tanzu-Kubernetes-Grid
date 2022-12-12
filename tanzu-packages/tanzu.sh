#!/bin/bash

source tanzu-lib.sh

# Set to overide automated discovery of harbor version
TANZU_PACKAGE_VERSION=

TANZU_PACKAGE_NAME=harbor
TANZU_PACKAGE=harbor.tanzu.vmware.com
TANZU_NAMESPACE=tanzu-packages
TANZU_VALUES_FILE=harbor-data-values.yaml

# Set to overide automated discovery of cert manager version
TANZU_CERTMANAGER_VERSION=

TANZU_CERTMAN_PACKAGE_NAME=cert-manager
TANZU_CERTMAN_PACKAGE=cert-manager.tanzu.vmware.com

# Set to overide automated discovery of contour version
TANZU_CONTOUR_VERSION=

TANZU_CONTOUR_PACKAGE=contour.tanzu.vmware.com
TANZU_CONTOUR_PACKAGE_NAME=contour
TANZU_CONTOUR_VALUES_FILE=contour-data-values.yaml

# Set to overide automated discovery of fluentBit version
TANZU_FLUENTBIT_VERSION=

TANZU_FLUENTBIT_PACKAGE=fluent-bit.tanzu.vmware.com
TANZU_FLUENTBIT_PACKAGE_NAME=fluent-bit
TANZU_FLUENTBIT_VALUES_FILE=fluent-bit-data-values.yaml

# Set to overide automated discovery of prometheus  version
TANZU_PROMETHEUS_VERSION=

TANZU_PROMETHEUS_PACKAGE=prometheus.tanzu.vmware.com
TANZU_PROMETHEUS_PACKAGE_NAME=prometheus
TANZU_PROMETHEUS_VALUES_FILE=prometheus-data-values.yaml

TANZU_KAPP_SECRET_FILE=kapp-secret.yaml

check_tools () {
  if [ ! command -v imgpkg &> /dev/null ]; then
    echo "Please install imgpkg"
  elif [ ! command -v yq &> /dev/null ]; then
    echo "Please install yq"
  fi
}

harbor_values_gen () {
  image_url=$(kubectl -n tanzu-package-repo-global get packages $TANZU_PACKAGE.$TANZU_PACKAGE_VERSION -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
  imgpkg pull -b $image_url -o /tmp/harbor-package
  cp /tmp/harbor-package/config/values.yaml $TANZU_VALUES_FILE
  bash /tmp/harbor-package/config/scripts/generate-passwords.sh $TANZU_VALUES_FILE
  yq -i eval '... comments=""' $TANZU_VALUES_FILE
}

harbor_install () {
  if [ -f "$TANZU_VALUES_FILE" ]; then
    tanzu package install $TANZU_PACKAGE_NAME --package-name $TANZU_PACKAGE --version $TANZU_PACKAGE_VERSION --values-file $TANZU_VALUES_FILE --namespace $TANZU_NAMESPACE
  else
    echo "Please generate a harbor values file first!"
  fi
}

harbor_update () {
  if [ -f "$TANZU_VALUES_FILE" ]; then
    tanzu package installed update $TANZU_PACKAGE_NAME --package-name $TANZU_PACKAGE --version $TANZU_PACKAGE_VERSION --values-file $TANZU_VALUES_FILE --namespace $TANZU_NAMESPACE
  else
    echo "No harbor values file found!"
  fi
}

harbor_delete () {
  tanzu package installed delete $TANZU_PACKAGE_NAME -n $TANZU_NAMESPACE
}

certman_install () {
  tanzu package install $TANZU_CERTMAN_PACKAGE_NAME --package-name $TANZU_CERTMAN_PACKAGE --version $TANZU_CERTMANAGER_VERSION --namespace $TANZU_NAMESPACE
}

certman_delete () {
  tanzu package installed delete $TANZU_CERTMAN_PACKAGE_NAME -n $TANZU_NAMESPACE
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

# In Development!
kapp_secret_gen () {
cat > $TANZU_KAPP_SECRET_FILE << EOF
---
apiVersion: v1
kind: Secret
metadata:
  # Name must be 'kapp-controller-config' for kapp controller to pick it up
  name: kapp-controller-config

  # Namespace must match the namespace kapp-controller is deployed to
  namespace: tkg-system

stringData:
  # A cert chain of trusted ca certs. These will be added to the system-wide
  # cert pool of trusted ca's (optional)
  caCerts: |
    -----BEGIN CERTIFICATE-----
    MIIDRjCCAi6gAwIBAgIRAI25RtCX3hLXTq9HCgFlmqswDQYJKoZIhvcNAQELBQAw
    FDESMBAGA1UEAxMJSGFyYm9yIENBMB4XDTIyMDYxMDA2NDEzM1oXDTMyMDYwNzA2
    NDEzM1owETEPMA0GA1UEAxMGaGFyYm9yMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
    MIIBCgKCAQEAtarn5+OlJ3DnGN96RxHkA8cUwPrevJgkSZDegdPwS78AVRBVtOKD
    0Gev62+NirEzJrx8Wu/1p9JEg5bbzaw5mHP0TiDCOuQhO0SRVZLz9pbBSsl8KXQe
    34TFwlyX9BPzzmun1+G5SR+71DsmFtG8Um7YuIaoYAJKdnazXEBGAjJdvOJunjFo
    hRJJBRLjhf/8qdIUnpXM2lWXMF+1IN6gPlyeF+89exx1xCAJCPCueOyJGF2YhLg/
    XYHYMoTobi1zXKZJZ3wGm/hVkUoivva2uJVyS95l8Lh3Cvfqx15BG4V09qSv6O15
    sUSryOiK0KvlyS+ECGVCaftZqdykP6nl1QIDAQABo4GVMIGSMB0GA1UdJQQWMBQG
    CCsGAQUFBwMBBggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFGnM
    02dJDjvcURDCjiQDTkh4rUBnMEIGA1UdEQQ7MDmCF2hhcmJvci5za3luZXRzeXN0
    ZW1zLmlvgh5ub3RhcnkuaGFyYm9yLnNreW5ldHN5c3RlbXMuaW8wDQYJKoZIhvcN
    AQELBQADggEBAAJoWzqLgT/2m6HXL22RPXyJgg0zkldmfxJAmtIV+fZGpZDdxEkV
    EQXwhjqpP5WkxkRCI69WzqNf4O0NojVZm2K9cnHKuKgh8qEhpiCoJRaxZnAFy167
    LjoGqtFz7BfjW7TTHDgPf/q441kb+K79EBtFOsfZY8EbG60ESffiuEFyUIZiursU
    pDaAKt1wbP5I0Xlkv0NS/PwpU/H9YBU1luUGKIvWkck2Spt+Bz+xtMw60NkKCrcz
    rlPvBWh9L2imKUULy0SYhD3ocihyW2fScf/WdAnXh4KtsnLmvIUETkvrXHbr5Eik
    4Gvy+UwsLqyRP/QBCNDXBxC++aTcx3r0JKU=
    -----END CERTIFICATE-----

  # fetching images or imgpkgBundles, will skip TLS verification. (optional)
  dangerousSkipTLSVerify: "harbor.skynetsystems.io"

  # JSON encoded array of kapp deploy rawOptions that are applied to all App CRs.
  # App CR specified rawOptions take precedence over what's specified here.
  # (optional; v0.37.0+)
  kappDeployRawOptions: "[\"--diff-changes=true\"]"
EOF
}

prometheus_install () {
  tanzu package install $TANZU_PROMETHEUS_PACKAGE_NAME --package-name $TANZU_PROMETHEUS_PACKAGE --version $TANZU_PROMETHEUS_VERSION --namespace $TANZU_NAMESPACE
}

kind_cleanup () {
docker ps -a | grep -v CONTAINER &> /dev/null
if [ $? -eq 0 ]; then
  echo "Deleting Kind clusters..."
  for i in $(docker ps -a | grep -v CONTAINER | awk '{print $1}'); do docker stop  $i; done
  for i in $(docker ps -a | grep -v CONTAINER | awk '{print $1}'); do docker rm  $i; done
else 
  echo "No kind clusters present!"
fi
docker volume ls | grep -v DRIVER &> /dev/null
if [ $? -eq 0 ]; then
  echo "Deleting all volumes"
  for i in $(docker volume ls | grep -v DRIVER | awk '{print $2}'); do docker volume rm  $i; done
else
  echo "No volumes present!"
fi
}

init_alias () {
  echo "Initializing aliases"
  alias k="kubectl"
  alias kgc="kubectl config get-contexts"
  alias kuc="kubectl config use-context"
  alias krr="kubectl rollout restart"
  alias kga="kubectl get all -A"
  alias tcl="tanzu cluster list --include-management-cluster"
}

contour_install () {
  tanzu package install $TANZU_CONTOUR_PACKAGE_NAME --package-name $TANZU_CONTOUR_PACKAGE --version $TANZU_CONTOUR_VERSION --values-file $TANZU_CONTOUR_VALUES_FILE --namespace $TANZU_NAMESPACE
}

# In Development !
kapp_secrets_gen_update () {
  kapp_secret_gen
}

begin () {
  if [ -z "$TANZU_PACKAGE_VERSION" ]; then
    TANZU_PACKAGE_VERSION=`tanzu package available list $TANZU_PACKAGE | grep $TANZU_PACKAGE | awk '{print $2}' | tail -1`
  fi
  
  if [ -z "$TANZU_CERTMANAGER_VERSION" ]; then
    TANZU_CERTMANAGER_VERSION=`tanzu package available list | grep cert-manager | awk '{print $5}'`
  fi
  
  if [ -z "$TANZU_CONTOUR_VERSION" ]; then
    TANZU_CONTOUR_VERSION=`tanzu package available list $TANZU_CONTOUR_PACKAGE | grep $TANZU_CONTOUR_PACKAGE_NAME | awk '{print $2}' | tail -1`
  fi
  
  if [ -z "$TANZU_FLUENTBIT_VERSION" ]; then
    TANZU_FLUENTBIT_VERSION=`tanzu package available list | grep $TANZU_FLUENTBIT_PACKAGE_NAME | awk '{print $12}'`
  fi
  
  if [ -z "$TANZU_PROMETHEUS_VERSION" ]; then
    TANZU_PROMETHEUS_VERSION=`tanzu package available list -A | grep $TANZU_PROMETHEUS_PACKAGE_NAME | awk '{print $10}'`
  fi

  echo
  echo "Harbor: v$TANZU_PACKAGE_VERSION  -----------------------------"
  echo
  echo "  1 - Generate values file"
  echo "  2 - Install package"
  echo "  3 - Update package"
  echo "  4 - Delete package"
  echo "  5 - List packages"
  echo
  echo "Cert Manager: v$TANZU_CERTMANAGER_VERSION -------------------------"
  echo
  echo "  6  - Install package"
  echo "  7  - Delete package"
  echo
  echo "Contour: v$TANZU_CONTOUR_VERSION --------------------------------"
  echo 
  echo "  8  - Generate values file"
  echo "  9  - Install package"
  echo
  echo "Fluent-bit: v$TANZU_FLUENTBIT_VERSION ------------------------------"
  echo
  echo "Prometheus: v$TANZU_PROMETHEUS_VERSION ------------------------------"
  echo
  echo "  10  - Generate values file"
  echo "  11  - Install package"
  echo
  echo "Kapp Secret: ---------------------------------------------------"
  echo
  echo "  12 - Generate secret (In Development)"
  echo
  echo "General administration:  --------------------------------"
  echo 
  echo "  13 - Initialize aliases"
  echo "  14 - Cleanup Kind cluster"
  echo
  echo "Select an option:"
  read choice
  
  case $choice in
    1) check_tools
       harbor_values_gen
       ;;
    2) harbor_install
       ;;
    3) harbor_update
       ;;
    4) harbor_delete 
       ;;
    5) tanzu package installed list -n $TANZU_NAMESPACE -A
       ;;
    6) certman_install
       ;;
    7) certman_delete
       ;;
    8) countour_values_gen
       ;;
    9) contour_install
       ;;
    10) echo
       ;;
    11) prometheus_install
       ;;
    12) kapp_secrets_gen_update
       ;;
    13) init_alias
       ;;
    14) kind_cleanup
       ;;
    *) echo "This choice is not valid"
  esac
}

init-cluster-yes-no () {
  echo
  echo "Cluster may be new, do you want to initialize?"
  echo
  echo "  1 - Yes"
  echo "  2 - No"
  echo
  echo "Select an option:"
  read choice

  case $choice in
    1) init-cluster
       ;;
    2) 
       ;;
    *) echo "This choice is not valid"
  esac
}

init-cluster () {
  cluster-rolebinding-apply
  kapp-controller-psp-apply
  kapp-controller-apply

  # wait for all pods to be ready before continuing
  echo Waiting for pods to be ready...
  sleep 5
  kubectl wait --for=condition=Ready  pod --all -n tkg-system --timeout=60s
  sleep 10

  tanzu-repo-16-add
  tanzu-packages-ns-create
}

tanzu package available list &> /dev/null 
if [ "$?" -eq 0 ]; then
  begin  
else
  init-cluster-yes-no
fi
