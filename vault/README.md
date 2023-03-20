![rabbitmq logo](rabbitmq.jpeg)

## HashiCorp Vault

[HashiCorp Vault](https://www.hashicorp.com/products/vault) secures application running on kubernetesby centrally managing and controlling access to secrets and encryption keys. Vault can store and dynamically distribute secrets such as tokens, passwords, certificates and encryption keys for secure access to infrastructure and applications. Vault also provides encryption-as-a-service with centralized key management and enables encryption of data in transit and at rest across the cloud, data center and the edge. Here are some of the key features of Vault:

-   **Secret Storage**: Vault supports a  [plethora of application and service choices](https://www.vaultproject.io/docs/configuration/storage)  as a storage backend for secret storage. Examples include MySQL, Cassandra, Consul, MSSQL, Azure and Google Cloud Storage. Vault offers a set of  [plugins](https://www.vaultproject.io/docs/secrets)  to integrate with these storage backends.
-   **Audit Logs**: Vault offers detailed audit logs to track client interactions for authentication, token creation, secret access and revocation. This provides a detailed audit trail and can be used to detect security anomalies and breaches. IT admins can further use this data to fine tune the security access policies and prove compliance with industry regulations.
-   **Dynamic Secrets**: Secrets can be programmatically generated on-demand for users and applications with an expiry timer (TTL) and an option to renew. Hence, secrets do not lurk around and they are generated as and when needed. If needed, secrets can also be revoked immediately after their use.
-   **API-Driven Encryption**: Vault offers Encryption-as-a-Service by providing HTTPS based APIs to encrypt and decrypt application data. This relieves the application developers from the burden of encrypting and decrypting application data and enables IT admins to centrally manage it through Vault.
-   **Policy-Driven Key Rotation**: Encryption keys can be rotated periodically or on-demand with Vault. As new keys are distributed throughout the environment, previously encrypted data can still be decrypted since both the old and new keys are saved in a keyring.

### Injecting Secrets into Kubernetes Pods via Vault Agent Containers

**Prerequisite**
```
git clone https://github.com/hashicorp/vault-guides.git
cd vault-guides/operations/provision-vault/kubernetes/minikube/vault-agent-sidecar
```
**1. Installing Vault**

Add HashiCorp repository to Helm 
```
$ > helm repo add hashicorp https://helm.releases.hashicorp.com
"hashicorp" has been added to your repositories
```
Update all the repositories to ensure `helm` is aware of the latest versions.
```
$ > helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "splunk-otel-collector-chart" chart repository
...Successfully got an update from the "ingress-nginx" chart repository
...Successfully got an update from the "hashicorp" chart repository
Update Complete. ⎈Happy Helming!⎈
```
Install the latest version of the Vault server running in development mode.
```
$ > helm install vault hashicorp/vault --set "server.dev.enabled=true"
NAME: vault
LAST DEPLOYED: Sun Mar 19 01:03:05 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
  ```
Display all the pods in the default namespace.
```
$ > kubectl get pods
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 1/1     Running   0          67s
vault-agent-injector-54bdddbb94-ktq5k   1/1     Running   0          68s
```
Development mode

Running a Vault server in development is automatically initialized and unsealed. This is ideal in a learning environment but NOT recommended for a production environment.

### Set a secret in Vault
The applications that you deploy in the  [Inject secrets into the pod](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#inject-secrets-into-the-pod)  section expect Vault to store a username and password stored at the path  `internal/database/config`. To create this secret requires that a  [key-value secret engine](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2)  is enabled and a username and password is put at the specified path.

Start an interactive shell session on the  `vault-0`  pod.
```
kubectl exec -it vault-0 -- /bin/sh
/ $
```
Enable kv-v2 secrets at the path `internal`.
```
/ $ vault secrets enable -path=internal kv-v2
Success! Enabled the kv-v2 secrets engine at: internal/
```
Create a secret at path `internal/database/config` with a `username` and `password`.
```
/ $ vault kv put internal/database/config username="admin" password="changeme"
======== Secret Path ========
internal/data/database/config

======= Metadata =======
Key                Value
---                -----
created_time       2023-03-19T01:05:47.624429281Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```
### Apply a template to the injected secrets

