![vault logo](vault.png)

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
### Configure Kubernetes authentication
Vault provides a  [Kubernetes authentication](https://developer.hashicorp.com/vault/docs/auth/kubernetes)  method that enables clients to authenticate with a Kubernetes Service Account Token. This token is provided to each pod when it is created.

Start an interactive shell session on the  `vault-0`  pod.
```
$ > kubectl exec -it vault-0 -- /bin/sh
/ $
```
Enable the Kubernetes authentication method.
```
$ > Enable the Kubernetes authentication method.
Success! Enabled kubernetes auth method at: kubernetes/
```
Vault accepts a service token from any client in the Kubernetes cluster. During authentication, Vault verifies that the service account token is valid by querying a token review Kubernetes endpoint.

Configure the Kubernetes authentication method to use the location of the Kubernetes API.
```
/ $ vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
Success! Data written to: auth/kubernetes/config
```
The environment variable  `KUBERNETES_PORT_443_TCP_ADDR`  is defined and references the internal network address of the Kubernetes host.

For a client to read the secret data defined at  `internal/database/config`, requires that the read capability be granted for the path  `internal/data/database/config`. This is an example of a  [policy](https://developer.hashicorp.com/vault/docs/concepts/policies). A policy defines a set of capabilities.

Write out the policy named  `internal-app`  that enables the  `read`  capability for secrets at path  `internal/data/database/config`.
```
vault policy write internal-app - <<EOF
path "internal/data/database/config" {
  capabilities = ["read"]
}
EOF
```
Create a Kubernetes authentication role named `internal-app`.
```
vault write auth/kubernetes/role/internal-app \
    bound_service_account_names=internal-app \
    bound_service_account_namespaces=default \
    policies=internal-app \
    ttl=24h
```
The role connects the Kubernetes service account,  `internal-app`, and namespace,  `default`, with the Vault policy,  `internal-app`. The tokens returned after authentication are valid for 24 hours.

### Define a Kubernetes service account
The Vault Kubernetes authentication role defined a Kubernetes service account named `internal-app` in the `default` namespace.

Create a Kubernetes service account named  `internal-app`  in the default namespace.

```
$ > kubectl create sa internal-app
```
### Launch an application
Install the following application into the default namespace.
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orgchart
  labels:
    app: orgchart
spec:
  selector:
    matchLabels:
      app: orgchart
  replicas: 1
  template:
    metadata:
      annotations:
      labels:
        app: orgchart
    spec:
      serviceAccountName: internal-app
      containers:
        - name: orgchart
          image: jweissig/app:0.0.1
```
The name of this deployment is `orgchart`. The `spec.template.spec.serviceAccountName` defines the service account `internal-app` to run this container.
```
$ > kubectl apply --filename deployment-orgchart.yaml
```
The Vault-Agent injector looks for deployments that define specific annotations. None of these annotations exist in the current deployment. This means that no secrets are present on the  `orgchart`  container in the  `orgchart`  pod.

Verify that no secrets are written to the  `orgchart`  container in the  `orgchart`  pod.

### Inject secrets into the pod
The deployment is running the pod with the  `internal-app`  Kubernetes service account in the default namespace. The Vault Agent Injector only modifies a deployment if it contains a specific set of annotations. An existing deployment may have its definition patched to include the necessary annotations.

Define the following patch to update the deployment  `patch-inject-secrets.yaml`
```
$ > cat patch-inject-secrets.yanml
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: 'true'
        vault.hashicorp.com/agent-inject-status: 'update'
        vault.hashicorp.com/role: 'internal-app'
        vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config'
```

These  [annotations](https://developer.hashicorp.com/vault/docs/platform/k8s/injector/annotations)  define a partial structure of the deployment schema and are prefixed with  `vault.hashicorp.com`.

-   [](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#)[`agent-inject`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject)  enables the Vault Agent Injector service
-   [](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#)[`role`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#role)  is the Vault Kubernetes authentication role
-   [](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#)[`agent-inject-secret-FILEPATH`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject-secret-filepath)  prefixes the path of the file,  `database-config.txt`  written to the  `/vault/secrets`  directory. The value is the path to the secret defined in Vault.

Patch the  `orgchart`  deployment defined in  `patch-inject-secrets.yaml`.

```
$ > kubectl patch deployment orgchart --patch "$(cat patch-inject-secrets.yaml)"
```

Wait until the re-deployed  `orgchart`  pod reports that it is  [`Running`](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase)  and ready (`2/2`).

This new pod now launches two containers. The application container, named  `orgchart`, and the Vault Agent container, named  `vault-agent`.

Display the secret written to the `orgchart` container.

```
kubectl exec \
    $(kubectl get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
    --container orgchart -- cat /vault/secrets/database-config.txt
data: map[password:db-secret-password username:db-readonly-user] metadata: map[created_time:2019-12-20T18:17:50.930264759Z deletion_time: destroyed:false version:2]
```
### Apply a template to the injected secrets
The schema of the injected secret may need to be structured in a way that the application understands. Before writing the secrets to the file system a template can structure the data. To apply this template a new set of annotations need to be applied.

```
$ > cat patch-secrets-as-template.yaml
spec: 
  template: 
    metadata: 
      annotations: 
        vault.hashicorp.com/agent-inject: 'true' 		     
        vault.hashicorp.com/agent-inject-status: 'update' 
        vault.hashicorp.com/role: 'internal-app' 
        vault.hashicorp.com/agent-inject-secret-database-config.txt: 'internal/data/database/config' 
        vault.hashicorp.com/agent-inject-template-database-config.txt: | 
          {{- with secret "internal/data/database/config" -}} 
          postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/wizard 
          {{- end -}}
```
This patch contains two new annotations:

-   [](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#)[`agent-inject-status`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject-status)  set to  `update`  informs the injector reinject these values.
-   [](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#)[`agent-inject-template-FILEPATH`](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar#agent-inject-template-filepath)  prefixes the file path. The value defines the  [Vault Agent template](https://developer.hashicorp.com/vault/docs/agent/template)  to apply to the secret's data.

The template formats the username and password as a PostgreSQL connection string.

Apply the updated annotations.
```
$ > kubectl patch deployment orgchart --patch "$(cat patch-inject-secrets-as-template.yaml)"
deployment.apps/exampleapp patched
```
Display the secret written to the `orgchart` container in the `orgchart` pod.
```
$ > kubectl exec \
    $(kubectl get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
    -c orgchart -- cat /vault/secrets/database-config.txt
    
postgresql://db-readonly-user:db-secret-password@postgres:5432/wizard
```

