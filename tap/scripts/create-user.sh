#!/bin/bash

# Use the following script to help you create a user in kubernetes for testing RBAC
# Usage: $ > create-user.sh test-user


if [ -z $1 ]; then 
  echo "Please provide the user name!"
  exit 1
fi

USER=$1

# Following command will generates an Ed25519 private key using OpenSSL.
openssl genpkey -out $USER.key -algorithm Ed25519
# In this example, the Common Name (CN) is set to “john” and the Organization (O) is set to “edit”.
openssl req -new -key $USER.key -out $USER.csr -subj "/CN=$USER,/O=test"

# Initiate the certificate signing request
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $USER
spec:
  request: $(cat user.csr | base64 -w 0)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - client auth
EOF

# By executing following command, you authorize the issuance of a certificate associated with the CSR,
# allowing the user to use the certificate for authentication and access within the Kubernetes cluster.
kubectl certificate approve $USER
kubectl get csr/$USER -o jsonpath="{.status.certificate}" | base64 -d > $USER.crt

# set credentials for a user named “john” using a Kubernetes configuration file named “john-kube-config”. 
# It specifies the client key, client certificate, and enables embedding of the certificates.
kubectl --kubeconfig $USER-kube-config config set-credentials $USER --client-key $USER.key --client-certificate $USER.csr --embed-certs=true

# Set kubeconfig if required
# kubectl --kubeconfig $USER-kube-config config set-context $USER --cluster <CLUSTER-NAME> --user $USER


# Add RBAC for newly created user ex.
# kubectl create clusterrolebinding test-app-operator --clusterrole=app-operator --user=test

# Test permisions ex
# kubectl auth can-i get accelerators --as=test
