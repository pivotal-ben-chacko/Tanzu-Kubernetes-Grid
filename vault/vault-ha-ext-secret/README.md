![vault logo](vault.png)

## HashiCorp Vault HA with External Secrets Operator

We will deploy Vault in HA mode with Replicas set to 3. Ensure you have at least 3 Kubernetes nodes in the Kubernetes cluster as the 3 Vault Pods ware Daemon sets and needs to be deployed on 3 separate nodes. If you see one Pod just waiting to initialize then this is the problem.

```
```

### Install Vault using Helm 

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
