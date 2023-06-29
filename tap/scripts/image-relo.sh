# update export settings based on where your connecting to

export IMGPKG_REGISTRY_HOSTNAME=harbor.skynetsystems.io
export IMGPKG_REGISTRY_USERNAME=admin
export IMGPKG_REGISTRY_PASSWORD=changeme
export TAP_VERSION=1.5.1

# imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION \
#   --to-tar tap-packages-$TAP_VERSION.tar \
#   --include-non-distributable-layers

imgpkg copy \ 
  --tar tap-packages-$TAP_VERSION.tar \
  --to-repo $IMGPKG_REGISTRY_HOSTNAME/tap/tap-packages \
  --registry-ca-cert-path ./harbor.crt
