![vault logo](../vault.png)

## HashiCorp Vault HA with External Secrets Operator

This tutorial walks through setting up end-to-end TLS on a HA Vault cluster in Kubernetes. You will create a private key and a widlcard certificate using the Kubernetes CA. You will store the certificate and the key in the [Kubernetes secrets store](https://kubernetes.io/docs/concepts/configuration/secret/). Finally you will configure the helm chart to use the kubernetes secret.

In the second part of the tutorial we will see how we can integrate Vault with [External Secrets Operator](https://external-secrets.io/) so that we synchronize and manage secrets within the cluster.

Deploy Vault in HA mode with Replicas set to 3. Ensure you have at least 3 Kubernetes nodes in the Kubernetes cluster as the 3 Vault Pods ware Daemon sets and needs to be deployed on 3 separate nodes. If you see one Pod just waiting to initialize then this is the problem.

```
kkubectl pod all
NAME                                        READY   STATUS    RESTARTS   AGE
pod/vault-0                                 0/1     Running   0          7m2s
pod/vault-1                                 0/1     Running   0          7m1s
pod/vault-2                                 0/1     Pending   0          7m
pod/vault-agent-injector-78f69bbd46-h65fm   1/1     Running   0          7m3s
```

### Prepare to install Vault

**Add vault repository**
```
$ > helm repo add hashicorp https://helm.releases.hashicorp.com
$ > helm repo update
```

Create a self signed certificate authority to generate TLS certificates from. We will use these to create a certificate issuer utilizing Certmanager, in order to generate TLS certificates for vault backend.

```
$ > openssl genrsa -out rootCAKey.pem 2048
$ > openssl req -x509 -sha256 -new -nodes -key rootCAKey.pem -days 3650 -out rootCACert.pem
```

Afterwards, create a secret to store the certificate and key generated previously.

```apiVersion: v1
kind: Secret
metadata:
  name: vault-ca-secret
  namespace: vault
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CR..... # Base64 encoded ca cert
  tls.key: LS0tLS1CR..... # Base54 encoded ca key
  ```

Next apply the secret, remember to create a namespace called vault first: 

```
$ > kubectl create ns vault
$ > kubectl apply -f vault-ca-secret.yaml
```

Next we will need to create a certificate issuer using the ca secret created in the previous step. More information about certificate issuer can be found here [cert-manager.io](https://cert-manager.io/docs/concepts/issuer/). 

```
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault-ca-issuer
  namespace: vault
spec:
  ca:
    secretName: vault-ca-secret
```

Next apply the file.

```
$ > kubectl apply -f vault-issuer.yaml
```

Ensure the issuer `READY` column is set to *True*

```
$ > kubectl get issuer
NAME              READY   AGE
vault-ca-issuer   True    31s
```

Next use the issuer to create a TLS certificate key pair for vault to use to secure the backend connections. 

Ensure the DNS entries are updated to reflect your environment. The following entries should not be changed:

DNS

 - vault-0.vault-internal
 - vault-1.vault-internal
 - vault-2.vault-internal

IP Addresses

 - 127.0.0.1

```
cat vault-tls-cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-tls
  namespace: vault
spec:
  secretName: vault-tls-secret
  dnsNames:
    - vault.skynetsystems.io
    - vault-0.vault-internal
    - vault-1.vault-internal
    - vault-2.vault-internal
  ipAddresses:
    - 127.0.0.1
  issuerRef:
    name: vault-ca-issuer
    # We can reference ClusterIssuer by changing the kind here.
    # The default value is Issuer (i.e. a locally namespaced Issuer)
    kind: Issuer
```

Ensure the TLS certificate has been generated successfully:

```
$ > kubectl get certificate
NAME        READY   SECRET             AGE
vault-tls   True    vault-tls-secret   109m  
```

### Install Vault using Helm chart

Create the following values.yaml file

```
---
global:
  enabled: true
  tlsDisable: false
server:
  ingress:
    enabled: false # Do not create ingress, we will creat a proxy
  readinessProbe:
    httpGet:
      enabled: true
      port: 8200
      scheme: HTTPS
      path: "/v1/sys/health?standbycode=204&sealedcode=204&uninitcode=204"
  livenessProbe:
    httpGet:
      enabled: true
      port: 8200
      scheme: HTTPS
      path: "/v1/sys/health?standbyok=true"
      initialDelaySeconds: 60
  auditStorage:
    enabled: true
  standalone:
    enabled: false
  extraEnvironmentVars:
    VAULT_CACERT: /vault/userconfig/vault-tls-secret/ca.crt
  extraVolumes:
    - type: secret
      name: vault-tls-secret # The TLS Secret Created Earlier
  ha:
    enabled: true
    replicas: 3
    address: "0.0.0.0:8200"
    cluster_address: "0.0.0.0:8201"
    raft:
      enabled: true
      config: |
        ui = true
        listener "tcp" {
          tls_disable = 0
          address = "0.0.0.0:8200"
          cluster_address = "0.0.0.0:8201"
          tls_cert_file = "/vault/userconfig/vault-tls-secret/tls.crt"
          tls_key_file = "/vault/userconfig/vault-tls-secret/tls.key"
          tls_client_ca_file = "/vault/userconfig/vault-tls-secret/ca.crt"
        }
        storage "raft" {
          path = "/vault/data"
            retry_join {
            leader_api_addr = "https://vault-0.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-tls-secret/ca.crt"
            leader_client_cert_file = "/vault/userconfig/vault-tls-secret/tls.crt"
            leader_client_key_file = "/vault/userconfig/vault-tls-secret/tls.key"
          }
          retry_join {
            leader_api_addr = "https://vault-1.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-tls-secret/ca.crt"
            leader_client_cert_file = "/vault/userconfig/vault-tls-secret/tls.crt"
            leader_client_key_file = "/vault/userconfig/vault-tls-secret/tls.key"
          }
          retry_join {
            leader_api_addr = "https://vault-2.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-tls-secret/ca.crt"
            leader_client_cert_file = "/vault/userconfig/vault-tls-secret/tls.crt"
            leader_client_key_file = "/vault/userconfig/vault-tls-secret/tls.key"
          }
        }
        service_registration "kubernetes" {}
ui:
  enabled: true
  serviceType: ClusterIP
  serviceNodePort: null
  externalPort: 8904
```

**Install Vault**

Install Vault and ensure all pods are up and running.
```
helm install vault hashicorp/vault --namespace vault -f values.yaml
```
Create a Proxy using the following yaml file. In the file we also need to provide the TLS Secret in order for the proxy to validate the back-end certificate of vault.

```
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: vault-api-proxy
  namespace: vault
spec:
  virtualhost:
    fqdn: vault.skynetsystems.io
    tls:
      secretName: vault-tls-secret
  routes:
  - services:
    - name: vault-active
      port: 8200
      protocol: tls
      validation:
        caSecret: vault-tls-secret
        subjectName: vault.skynetsystems.io
    timeoutPolicy:
      idle: 45s
      response: 45s
```

